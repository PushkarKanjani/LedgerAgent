"""
LedgerAgent — Mock Enterprise Resource Planning (ERP) API (Durable DB Mode)
=============================================================================
Architecture Specification (Checkpoint 1 Deliverable 3 - Refined)
Module: mock_erp/app/main.py
Port: 8001 (Isolated Mock ERP Service)
Standards Reference: AGENTS.md Free-Tier & Local Testability Standards
=============================================================================
"""

import os
from fastapi import FastAPI, HTTPException, Query, status, Depends
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import date, datetime
from difflib import SequenceMatcher
import uvicorn
from sqlalchemy.orm import Session

from backend.app.models.db import (
    PurchaseOrder as DBPurchaseOrder,
    GoodsReceipt as DBGoodsReceipt,
    GLEntry as DBGLEntry,
    get_db,
    seed_database_defaults
)

app = FastAPI(
    title="Mock Enterprise ERP API",
    version="2.0.0",
    description="Standalone Mock ERP service simulating SAP / NetSuite endpoints with durable database backing."
)

# Seed database tables on boot
seed_database_defaults()


# =============================================================================
# 1. PYDANTIC SCHEMAS & API CONTRACTS
# =============================================================================

class POLineItem(BaseModel):
    po_line: int = Field(..., json_schema_extra={"example": 1})
    item_code: str = Field(..., json_schema_extra={"example": "SRV-CLOUD-01"})
    description: str = Field(..., json_schema_extra={"example": "Cloud Compute Task Worker (Hours)"})
    quantity: float = Field(..., gt=0, json_schema_extra={"example": 100.0})
    unit_price: float = Field(..., gt=0, json_schema_extra={"example": 45.00})
    line_total: float = Field(..., gt=0, json_schema_extra={"example": 4500.00})


class PurchaseOrderResponse(BaseModel):
    po_number: str = Field(..., json_schema_extra={"example": "PO-2026-8891"})
    vendor_name: str = Field(..., json_schema_extra={"example": "Apex Cloud Solutions LLC"})
    vendor_code: str = Field(..., json_schema_extra={"example": "VEND-00104"})
    po_date: str = Field(..., json_schema_extra={"example": "2026-07-15"})
    currency: str = Field(default="USD", json_schema_extra={"example": "USD"})
    subtotal: float = Field(..., json_schema_extra={"example": 4500.00})
    tax_amount: float = Field(..., json_schema_extra={"example": 360.00})
    total_amount: float = Field(..., json_schema_extra={"example": 4860.00})
    line_items: List[POLineItem]
    status: str = Field(default="OPEN", json_schema_extra={"example": "OPEN"})


class GoodsReceiptLine(BaseModel):
    receipt_line: int = Field(..., json_schema_extra={"example": 1})
    item_code: str = Field(..., json_schema_extra={"example": "SRV-CLOUD-01"})
    quantity_received: float = Field(..., gt=0, json_schema_extra={"example": 100.0})
    condition: str = Field(default="ACCEPTED", json_schema_extra={"example": "ACCEPTED"})


class GoodsReceiptResponse(BaseModel):
    receipt_number: str = Field(..., json_schema_extra={"example": "GR-2026-0412"})
    po_number: str = Field(..., json_schema_extra={"example": "PO-2026-8891"})
    received_date: str = Field(..., json_schema_extra={"example": "2026-07-20"})
    received_by: str = Field(..., json_schema_extra={"example": "operations_lead@company.internal"})
    line_items: List[GoodsReceiptLine]
    notes: Optional[str] = None


class VendorResponse(BaseModel):
    vendor_code: str
    vendor_name: str
    match_score: float = Field(..., description="Fuzzy match similarity (0.0 - 1.0)")
    tax_id: str
    payment_terms: str
    status: str


class GLEntryRequest(BaseModel):
    invoice_id: str = Field(..., description="UUID of the reconciled invoice (for idempotency)")
    po_number: Optional[str] = Field(None, json_schema_extra={"example": "PO-2026-8891"})
    vendor_code: str = Field(..., json_schema_extra={"example": "VEND-00104"})
    transaction_date: Optional[str] = None
    debit_account: str = Field(..., json_schema_extra={"example": "5000-EXPENSE-COGS"})
    credit_account: str = Field(default="2000-ACCOUNTS-PAYABLE", json_schema_extra={"example": "2000-ACCOUNTS-PAYABLE"})
    amount: float = Field(..., gt=0, json_schema_extra={"example": 4860.00})
    currency: str = Field(default="USD", json_schema_extra={"example": "USD"})
    description: str = Field(..., json_schema_extra={"example": "Invoice Reconciled by LedgerAgent"})


class GLEntryResponse(BaseModel):
    gl_reference_id: str
    invoice_id: str
    posted_at: datetime
    status: str = "POSTED"
    message: str


# =============================================================================
# 2. SYNTHETIC VENDORS DATABASE
# =============================================================================

SYNTHETIC_VENDORS = [
    {"vendor_code": "VEND-00101", "vendor_name": "Acme Industrial Supplies Inc.", "tax_id": "XX-XXX4102", "payment_terms": "NET30", "status": "ACTIVE"},
    {"vendor_code": "VEND-00102", "vendor_name": "Globex Logistics Logistics Corp", "tax_id": "XX-XXX8921", "payment_terms": "NET15", "status": "ACTIVE"},
    {"vendor_code": "VEND-00103", "vendor_name": "Initech Office Solutions", "tax_id": "XX-XXX5512", "payment_terms": "NET30", "status": "ACTIVE"},
    {"vendor_code": "VEND-00104", "vendor_name": "Apex Cloud Solutions LLC", "tax_id": "XX-XXX7733", "payment_terms": "NET30", "status": "ACTIVE"},
    {"vendor_code": "VEND-00105", "vendor_name": "Stark Hardware & Logistics", "tax_id": "XX-XXX9920", "payment_terms": "NET60", "status": "ACTIVE"},
]


# =============================================================================
# 3. REST ENDPOINTS (Durable DB Backed)
# =============================================================================

@app.get("/health", tags=["Health"])
def health_check():
    """Health check for Mock ERP dependency probing."""
    return {
        "status": "HEALTHY",
        "service": "Mock ERP System v2.0",
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/vendors/lookup", response_model=List[VendorResponse], tags=["Vendors"])
def lookup_vendor(query: str = Query(..., min_length=2, description="Extracted vendor string for fuzzy resolution")):
    """Performs fuzzy matching across synthetic ERP vendor master records."""
    results = []
    for vendor in SYNTHETIC_VENDORS:
        ratio = SequenceMatcher(None, query.lower(), vendor["vendor_name"].lower()).ratio()
        if ratio >= 0.40 or query.lower() in vendor["vendor_name"].lower():
            results.append(VendorResponse(
                vendor_code=vendor["vendor_code"],
                vendor_name=vendor["vendor_name"],
                match_score=round(ratio, 3),
                tax_id=vendor["tax_id"],
                payment_terms=vendor["payment_terms"],
                status=vendor["status"]
            ))

    results.sort(key=lambda x: x.match_score, reverse=True)
    if not results:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Vendor '{query}' could not be matched with confidence >= 0.40."
        )
    return results


@app.get("/purchase-orders/{po_number}", response_model=PurchaseOrderResponse, tags=["Purchase Orders"])
def get_purchase_order(po_number: str, db: Session = Depends(get_db)):
    """Retrieves purchase order commitments from the database."""
    po = db.query(DBPurchaseOrder).filter(DBPurchaseOrder.po_number == po_number).first()
    if not po:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Purchase order '{po_number}' not found in ERP records."
        )

    lines = [POLineItem(**l) for l in (po.line_items or [])]
    return PurchaseOrderResponse(
        po_number=po.po_number,
        vendor_name=po.vendor_name,
        vendor_code=po.vendor_code,
        po_date=po.po_date,
        currency=po.currency or "USD",
        subtotal=po.subtotal,
        tax_amount=po.tax_amount or 0.0,
        total_amount=po.total_amount,
        line_items=lines,
        status=po.status or "OPEN"
    )


@app.get("/goods-receipts", response_model=List[GoodsReceiptResponse], tags=["Goods Receipts"])
def get_goods_receipts(po_number: str = Query(..., description="PO number to filter delivery receipts"), db: Session = Depends(get_db)):
    """Retrieves delivery receipts associated with a purchase order from DB."""
    receipts = db.query(DBGoodsReceipt).filter(DBGoodsReceipt.po_number == po_number).all()
    if not receipts:
        return []

    results = []
    for r in receipts:
        lines = [GoodsReceiptLine(**l) for l in (r.line_items or [])]
        results.append(GoodsReceiptResponse(
            receipt_number=r.receipt_number,
            po_number=r.po_number,
            received_date=r.received_date,
            received_by=r.received_by,
            line_items=lines,
            notes=r.notes
        ))
    return results


@app.post("/gl-entries", response_model=GLEntryResponse, status_code=status.HTTP_201_CREATED, tags=["General Ledger"])
def post_gl_entry(entry: GLEntryRequest, db: Session = Depends(get_db)):
    """
    Submits double-entry accounting record to Mock ERP database.
    Guarantees idempotency on invoice_id.
    """
    existing = db.query(DBGLEntry).filter(DBGLEntry.invoice_id == entry.invoice_id).first()
    if existing:
        return GLEntryResponse(
            gl_reference_id=existing.gl_reference_id,
            invoice_id=existing.invoice_id,
            posted_at=existing.posted_at or datetime.utcnow(),
            status="POSTED",
            message="Idempotency match: GL entry was already posted in database."
        )

    gl_ref = f"GL-ERP-{entry.invoice_id[:8]}"
    db_entry = DBGLEntry(
        gl_reference_id=gl_ref,
        invoice_id=entry.invoice_id,
        po_number=entry.po_number or "PO-2026-8891",
        vendor_code=entry.vendor_code,
        vendor_name="Apex Cloud Solutions LLC",
        transaction_date=entry.transaction_date or datetime.utcnow().strftime("%Y-%m-%d"),
        debit_account=entry.debit_account,
        credit_account=entry.credit_account,
        amount=entry.amount,
        currency=entry.currency,
        description=entry.description,
        posted_by="MOCK_ERP_AGENT"
    )
    try:
        db.add(db_entry)
        db.commit()
    except Exception:
        db.rollback()
        existing_after_race = db.query(DBGLEntry).filter(DBGLEntry.invoice_id == entry.invoice_id).first()
        if existing_after_race:
            gl_ref = existing_after_race.gl_reference_id

    return GLEntryResponse(
        gl_reference_id=gl_ref,
        invoice_id=entry.invoice_id,
        posted_at=datetime.utcnow(),
        status="POSTED",
        message="Journal entry posted to General Ledger."
    )


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
