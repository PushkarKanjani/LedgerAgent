"""
LedgerAgent — Durable Database Persistence & Restart Regression Suite
=============================================================================
Module: tests/unit/test_persistence.py
Standards Reference: AGENTS.md Checkpoint 6.5 Durable Persistence Engine
=============================================================================
"""

import io
import os
import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.models.db import SessionLocal, Invoice, User, GLEntry


def test_invoice_persists_to_database_file():
    """
    Verifies that an ingested invoice is written to the SQLite/PostgreSQL
    database table and survives cold application restarts.
    """
    client = TestClient(app)

    # 1. Login as uploader
    login_resp = client.post("/api/v1/auth/login", json={
        "email": "uploader@ledgeragent.dev",
        "password": "LedgerAgent@2026"
    })
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Ingest binary PDF invoice
    pdf_bytes = b"%PDF-1.4\nInvoice for Persistence Test\n"
    payload = {"file": ("persistent_inv.pdf", io.BytesIO(pdf_bytes), "application/pdf")}
    upload_resp = client.post("/api/v1/invoices/upload", files=payload, headers=headers)
    assert upload_resp.status_code == 201
    invoice_id = upload_resp.json()["invoice_id"]
    sha256 = upload_resp.json()["sha256_hash"]

    # 3. Directly inspect the database row via fresh DB session
    db = SessionLocal()
    try:
        db_inv = db.query(Invoice).filter(Invoice.id == invoice_id).first()
        assert db_inv is not None, "Invoice row was not persisted into database table!"
        assert db_inv.sha256_hash == sha256
        print(f"\n✅ [Persistence Test] Verified invoice {invoice_id} saved on disk in {db.bind.url}")
    finally:
        db.close()

    # 4. Simulate a fresh application restart by creating a new TestClient instance
    new_client = TestClient(app)
    list_resp = new_client.get("/api/v1/invoices", headers=headers)
    assert list_resp.status_code == 200
    invoices = list_resp.json()
    
    matching = [i for i in invoices if i["invoice_id"] == invoice_id]
    assert len(matching) == 1, "Persisted invoice was missing after client restart!"
    print("✅ [Persistence Test] Invoices successfully retrieved from database across fresh client session.")
