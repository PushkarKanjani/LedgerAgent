"""
LedgerAgent — Pydantic Schemas for Structured Output & Validation
=============================================================================
Module: backend/app/agent/schemas.py
Standards Reference: AGENTS.md Type Safety & Zero-Bytes Response Models
=============================================================================
"""

from pydantic import BaseModel, Field, field_validator
from typing import List, Optional, Dict, Any, Literal
from datetime import date, datetime
import uuid


# =============================================================================
# 1. INVOICE EXTRACTION & LINE ITEM SCHEMAS
# =============================================================================

class InvoiceLineItem(BaseModel):
    item_code: str = Field(..., json_schema_extra={"example": "SRV-CLOUD-01"})
    description: str = Field(..., json_schema_extra={"example": "Cloud Compute Task Worker (Hours)"})
    quantity: float = Field(..., gt=0, json_schema_extra={"example": 100.0})
    unit_price: float = Field(..., gt=0, json_schema_extra={"example": 45.00})
    line_total: float = Field(..., gt=0, json_schema_extra={"example": 4500.00})

    @field_validator("line_total")
    @classmethod
    def validate_line_total(cls, v: float, info) -> float:
        qty = info.data.get("quantity")
        price = info.data.get("unit_price")
        if qty is not None and price is not None:
            expected = round(qty * price, 2)
            if abs(v - expected) > 0.05:
                raise ValueError(f"Line total {v} does not equal quantity * unit_price ({expected})")
        return v


class InvoiceExtraction(BaseModel):
    vendor_name: str = Field(..., min_length=2, json_schema_extra={"example": "Apex Cloud Solutions LLC"})
    vendor_tax_id: Optional[str] = Field(None, json_schema_extra={"example": "XX-XXX7733"})
    invoice_number: str = Field(..., min_length=1, json_schema_extra={"example": "INV-2026-0911"})
    po_number: Optional[str] = Field(None, json_schema_extra={"example": "PO-2026-8891"})
    invoice_date: date = Field(..., json_schema_extra={"example": "2026-07-22"})
    due_date: Optional[date] = Field(None, json_schema_extra={"example": "2026-08-22"})
    currency: str = Field(default="USD", min_length=3, max_length=3, json_schema_extra={"example": "USD"})
    subtotal: float = Field(..., ge=0, json_schema_extra={"example": 4500.00})
    tax_amount: float = Field(default=0.00, ge=0, json_schema_extra={"example": 360.00})
    total_amount: float = Field(..., ge=0, json_schema_extra={"example": 4860.00})
    line_items: List[InvoiceLineItem] = Field(default_factory=list)
    field_confidences: Dict[str, float] = Field(default_factory=dict)
    overall_confidence: float = Field(..., ge=0.0, le=1.0, json_schema_extra={"example": 0.965})
    raw_ocr_text: Optional[str] = Field(None)

    @field_validator("total_amount")
    @classmethod
    def validate_grand_total(cls, v: float, info) -> float:
        subtotal = info.data.get("subtotal")
        tax = info.data.get("tax_amount", 0.0)
        if subtotal is not None and tax is not None:
            expected = round(subtotal + tax, 2)
            if abs(v - expected) > 0.10:
                raise ValueError(f"Grand total {v} does not equal subtotal ({subtotal}) + tax ({tax}) = {expected}")
        return v


# =============================================================================
# 2. THREE-WAY RECONCILIATION & MATCH SCHEMAS
# =============================================================================

class LineMatchDetail(BaseModel):
    item_code: str
    invoiced_qty: float
    po_qty: Optional[float] = None
    received_qty: Optional[float] = None
    unit_price_variance: float = 0.0
    status: Literal["MATCHED", "PRICE_MISMATCH", "QUANTITY_MISMATCH", "UNRECEIVED"]


class ThreeWayMatchResult(BaseModel):
    invoice_id: str
    po_number: Optional[str] = None
    match_status: Literal[
        "FULL_MATCH",
        "PARTIAL_MATCH_WITHIN_TOLERANCE",
        "PRICE_MISMATCH",
        "QUANTITY_MISMATCH",
        "MISSING_PO",
        "MISSING_RECEIPT",
        "VENDOR_MISMATCH",
        "CURRENCY_MISMATCH"
    ]
    invoice_total: float
    po_total: Optional[float] = None
    received_total: Optional[float] = None
    price_variance: float = 0.0
    quantity_variance: float = 0.0
    variance_percentage: float = 0.0
    within_tolerance: bool = False
    discrepancy_reasons: List[str] = Field(default_factory=list)
    line_level_matches: List[LineMatchDetail] = Field(default_factory=list)
    evaluated_at: datetime = Field(default_factory=datetime.utcnow)


# =============================================================================
# 3. HUMAN-IN-THE-LOOP (HITL) APPROVAL SCHEMAS
# =============================================================================

class HITLApprovalRequest(BaseModel):
    approval_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    invoice_id: str
    requires_approval_reason: str
    confidence_score: float
    extracted_data: Optional[InvoiceExtraction] = None
    match_result: Optional[ThreeWayMatchResult] = None
    status: Literal["PENDING", "RESOLVED", "EXPIRED"] = "PENDING"
    assigned_at: datetime = Field(default_factory=datetime.utcnow)


class HITLDecisionPayload(BaseModel):
    decision: Literal["APPROVED", "REJECTED", "CORRECTED_AND_APPROVED", "ESCALATED"]
    reviewer_user_id: str = Field(..., json_schema_extra={"example": "pushkar_lead_reviewer"})
    reviewer_notes: Optional[str] = Field(None, json_schema_extra={"example": "Approved via LedgerAgent React HITL Dashboard"})
    corrected_payload: Optional[Dict[str, Any]] = None


# =============================================================================
# 4. GENERAL LEDGER (GL) ENTRY & AUDIT SCHEMAS
# =============================================================================

class GLEntry(BaseModel):
    gl_reference_id: str = Field(..., json_schema_extra={"example": "GL-ERP-1001"})
    invoice_id: str
    po_number: Optional[str] = None
    vendor_code: str = Field(..., json_schema_extra={"example": "VEND-00104"})
    transaction_date: date = Field(default_factory=date.today)
    debit_account: str = Field(default="5000-EXPENSE-COGS", json_schema_extra={"example": "5000-EXPENSE-COGS"})
    credit_account: str = Field(default="2000-ACCOUNTS-PAYABLE", json_schema_extra={"example": "2000-ACCOUNTS-PAYABLE"})
    amount: float = Field(..., gt=0, json_schema_extra={"example": 4860.00})
    currency: str = Field(default="USD", json_schema_extra={"example": "USD"})
    description: str = Field(..., json_schema_extra={"example": "Automated reconciliation by LedgerAgent"})
    posted_by: str = Field(default="LEDGER_AGENT_SYSTEM")
    posted_at: datetime = Field(default_factory=datetime.utcnow)


class AuditLogRecord(BaseModel):
    id: Optional[int] = None
    invoice_id: str
    trace_id: Optional[str] = None
    agent_node: str
    action: str
    actor_type: Literal["AGENT", "USER", "SYSTEM"] = "AGENT"
    actor_id: str = "ledger_agent"
    previous_state: Optional[Dict[str, Any]] = None
    new_state: Optional[Dict[str, Any]] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=datetime.utcnow)


# =============================================================================
# 5. STRICT JSON-SAFE API REQUEST / RESPONSE SCHEMAS (ZERO RAW BYTES)
# =============================================================================

class InvoiceUploadResponse(BaseModel):
    """Strictly JSON-safe response model for invoice uploads. Contains zero raw binary bytes."""
    invoice_id: str
    sha256_hash: str
    filename: str
    status: str
    message: str
    overall_confidence: Optional[float] = None
    match_status: Optional[str] = None
    requires_hitl: bool = False
    gl_reference_id: Optional[str] = None
    error_message: Optional[str] = None


class InvoiceStatusResponse(BaseModel):
    invoice_id: str
    sha256_hash: str
    filename: str
    status: str
    overall_confidence: Optional[float] = None
    match_status: Optional[str] = None
    requires_hitl: bool = False
    gl_reference_id: Optional[str] = None
    error_message: Optional[str] = None
    updated_at: datetime
