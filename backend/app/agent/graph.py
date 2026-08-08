"""
LedgerAgent — LangGraph State Machine
=============================================================================
Module: backend/app/agent/graph.py
Standards Reference: AGENTS.md Stateful Workflows & Redis Checkpointing
=============================================================================
"""

import os
from typing import TypedDict, Optional, List, Dict, Any, Literal
from datetime import datetime

# LangGraph Core Imports
from langgraph.graph import StateGraph, START, END
from langgraph.checkpoint.memory import MemorySaver

# Import node functions from nodes.py
from backend.app.agent.nodes import (
    ingest_node,
    ocr_extract_node,
    fallback_ocr_node,
    validate_extraction_node,
    three_way_match_node,
    post_to_gl_node,
    log_audit_node
)


# =============================================================================
# 1. TYPEDDICT STATE DEFINITION
# =============================================================================
class LedgerAgentState(TypedDict, total=False):
    invoice_id: str
    sha256_hash: str
    s3_key: str
    raw_file_bytes: Optional[bytes]
    raw_ocr_text: Optional[str]
    status: str
    ocr_engine_used: Optional[str]
    retry_count: int
    extracted_data: Optional[Dict[str, Any]]
    match_result: Optional[Dict[str, Any]]
    requires_hitl: bool
    hitl_reason: Optional[str]
    hitl_decision: Optional[Dict[str, Any]]
    gl_reference_id: Optional[str]
    error_message: Optional[str]
    audit_events: List[Dict[str, Any]]


# =============================================================================
# 2. ADDITIONAL STATE NODES & ROUTERS
# =============================================================================

def hitl_decision_node(state: LedgerAgentState) -> Dict[str, Any]:
    """Halts workflow execution for human reviewer evaluation."""
    events = list(state.get("audit_events") or [])
    events.append({
        "agent_node": "hitl_decision",
        "action": "WAITING_FOR_HUMAN_APPROVAL",
        "timestamp": datetime.utcnow().isoformat()
    })
    return {"status": "HITL_PENDING", "audit_events": events}


def dead_letter_node(state: LedgerAgentState) -> Dict[str, Any]:
    """Quarantine unrecoverable invoice."""
    return {"status": "FAILED_DEAD_LETTER"}


def route_ocr_result(state: LedgerAgentState) -> Literal["validate_extraction", "fallback_ocr", "dead_letter"]:
    if state.get("ocr_engine_used") == "TEXTRACT":
        return "validate_extraction"
    elif state.get("retry_count", 0) < 2:
        return "fallback_ocr"
    return "dead_letter"


def route_match_decision(state: LedgerAgentState) -> Literal["post_to_gl", "hitl_decision"]:
    extracted = state.get("extracted_data") or {}
    match = state.get("match_result") or {}
    
    confidence = extracted.get("overall_confidence", 0.0)
    match_status = match.get("match_status", "")
    within_tolerance = match.get("within_tolerance", False)
    
    # Auto-approve only if confidence >= 0.85 and match is full or within tolerance
    if confidence >= 0.85 and (match_status == "FULL_MATCH" or within_tolerance):
        return "post_to_gl"
    return "hitl_decision"


def route_hitl_outcome(state: LedgerAgentState) -> Literal["post_to_gl", "log_audit", "dead_letter"]:
    decision_obj = state.get("hitl_decision") or {}
    decision = decision_obj.get("decision")
    
    if decision in ("APPROVED", "CORRECTED_AND_APPROVED"):
        return "post_to_gl"
    elif decision == "REJECTED":
        return "log_audit"
    return "dead_letter"


# =============================================================================
# 3. GRAPH BUILDER & FACTORY
# =============================================================================

def create_ledger_agent_graph(checkpointer=None):
    """Compiles the stateful graph with memory or Redis checkpointer."""
    workflow = StateGraph(LedgerAgentState)
    
    workflow.add_node("ingest", ingest_node)
    workflow.add_node("ocr_extract", ocr_extract_node)
    workflow.add_node("fallback_ocr", fallback_ocr_node)
    workflow.add_node("validate_extraction", validate_extraction_node)
    workflow.add_node("three_way_match", three_way_match_node)
    workflow.add_node("hitl_decision", hitl_decision_node)
    workflow.add_node("post_to_gl", post_to_gl_node)
    workflow.add_node("log_audit", log_audit_node)
    workflow.add_node("dead_letter", dead_letter_node)
    
    workflow.add_edge(START, "ingest")
    workflow.add_edge("ingest", "ocr_extract")
    
    workflow.add_conditional_edges(
        "ocr_extract",
        route_ocr_result,
        {
            "validate_extraction": "validate_extraction",
            "fallback_ocr": "fallback_ocr",
            "dead_letter": "dead_letter"
        }
    )
    workflow.add_edge("fallback_ocr", "validate_extraction")
    workflow.add_edge("validate_extraction", "three_way_match")
    
    workflow.add_conditional_edges(
        "three_way_match",
        route_match_decision,
        {
            "post_to_gl": "post_to_gl",
            "hitl_decision": "hitl_decision"
        }
    )
    
    workflow.add_conditional_edges(
        "hitl_decision",
        route_hitl_outcome,
        {
            "post_to_gl": "post_to_gl",
            "log_audit": "log_audit",
            "dead_letter": "dead_letter"
        }
    )
    
    workflow.add_edge("post_to_gl", "log_audit")
    workflow.add_edge("log_audit", END)
    workflow.add_edge("dead_letter", END)
    
    cp = checkpointer or MemorySaver()
    return workflow.compile(
        checkpointer=cp,
        interrupt_before=["hitl_decision"]
    )


# Singleton in-memory graph for local fast testing
_GLOBAL_GRAPH = None

def get_graph():
    global _GLOBAL_GRAPH
    if _GLOBAL_GRAPH is None:
        _GLOBAL_GRAPH = create_ledger_agent_graph()
    return _GLOBAL_GRAPH
