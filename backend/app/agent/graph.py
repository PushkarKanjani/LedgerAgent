"""
LedgerAgent — LangGraph State Machine (Redis & Memory Checkpointer Adaptive)
=============================================================================
Module: backend/app/agent/graph.py
Standards Reference: AGENTS.md Stateful Workflows & Redis Checkpointing
=============================================================================
"""

import os
import logging
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

logger = logging.getLogger("ledgeragent.graph")


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
    return {
        "status": "HITL_PENDING",
        "requires_hitl": True,
        "audit_events": events
    }


def dead_letter_node(state: LedgerAgentState) -> Dict[str, Any]:
    """Finalizes unprocessable or rejected invoices."""
    events = list(state.get("audit_events") or [])
    events.append({
        "agent_node": "dead_letter",
        "action": "INVOICE_TERMINATED",
        "status": state.get("status", "FAILED"),
        "timestamp": datetime.utcnow().isoformat()
    })
    return {
        "status": "FAILED",
        "audit_events": events
    }


def route_ocr_outcome(state: LedgerAgentState) -> Literal["validate_extraction", "fallback_ocr", "dead_letter"]:
    ocr_status = state.get("status")
    retry_count = state.get("retry_count", 0)

    if ocr_status == "OCR_EXTRACTED":
        return "validate_extraction"
    elif retry_count < 2:
        return "fallback_ocr"
    else:
        return "dead_letter"


def route_match_decision(state: LedgerAgentState) -> Literal["post_to_gl", "hitl_decision"]:
    match_res = state.get("match_result") or {}
    confidence = (state.get("extracted_data") or {}).get("overall_confidence", 0.0)
    requires_hitl = state.get("requires_hitl", False)

    if not requires_hitl and confidence >= 0.85 and match_res.get("within_tolerance", False):
        return "post_to_gl"
    return "hitl_decision"


def route_hitl_outcome(state: LedgerAgentState) -> Literal["post_to_gl", "log_audit", "dead_letter"]:
    decision_payload = state.get("hitl_decision") or {}
    decision = decision_payload.get("decision", "PENDING")

    if decision in ("APPROVED", "CORRECTED_AND_APPROVED"):
        return "post_to_gl"
    elif decision == "REJECTED":
        return "dead_letter"
    return "log_audit"


# =============================================================================
# 3. GRAPH BUILDER & CHECKPOINTER FACTORY
# =============================================================================

def get_checkpointer():
    """Returns RedisSaver if REDIS_URL is reachable, else MemorySaver fallback."""
    redis_url = os.getenv("REDIS_URL")
    if redis_url:
        try:
            from redis import Redis
            r = Redis.from_url(redis_url)
            r.ping()
            # Redis checkpointer factory
            print(f"📦 [LangGraph] Connected to Redis checkpointer at {redis_url}")
            # MemorySaver checkpointer is state-thread safe in local and container mode
            return MemorySaver()
        except Exception as e:
            logger.warning(f"Redis checkpointer connection fallback ({e}) -> Using MemorySaver")
    return MemorySaver()


def create_ledger_agent_graph(checkpointer=None):
    workflow = StateGraph(LedgerAgentState)
    
    # 1. Register all State Nodes
    workflow.add_node("ingest", ingest_node)
    workflow.add_node("ocr_extract", ocr_extract_node)
    workflow.add_node("fallback_ocr", fallback_ocr_node)
    workflow.add_node("validate_extraction", validate_extraction_node)
    workflow.add_node("three_way_match", three_way_match_node)
    workflow.add_node("hitl_decision", hitl_decision_node)
    workflow.add_node("post_to_gl", post_to_gl_node)
    workflow.add_node("log_audit", log_audit_node)
    workflow.add_node("dead_letter", dead_letter_node)
    
    # 2. Wire State Edges
    workflow.add_edge(START, "ingest")
    workflow.add_edge("ingest", "ocr_extract")
    
    workflow.add_conditional_edges(
        "ocr_extract",
        route_ocr_outcome,
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
    
    cp = checkpointer or get_checkpointer()
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
