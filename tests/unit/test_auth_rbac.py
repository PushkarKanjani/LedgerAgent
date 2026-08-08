"""
LedgerAgent — Auth & RBAC Security Regression Suite
=============================================================================
Module: tests/unit/test_auth_rbac.py
Standards Reference: AGENTS.md Checkpoint 2 Security Audit
=============================================================================
"""

import io
import pytest
from fastapi.testclient import TestClient
from backend.app.main import app

client = TestClient(app)


def test_unauthenticated_upload_returns_401():
    """Verifies that invoice upload without Authorization header returns HTTP 401."""
    pdf_bytes = b"%PDF-1.4\nTest unauthenticated upload\n"
    payload = {"file": ("unauth.pdf", io.BytesIO(pdf_bytes), "application/pdf")}

    response = client.post("/api/v1/invoices/upload", files=payload)
    assert response.status_code == 401, f"Expected 401, got {response.status_code}: {response.text}"
    assert "detail" in response.json()
    print("\n✅ [Pass] Unauthenticated upload correctly blocked with 401 Unauthorized")


def test_uploader_can_upload_but_cannot_approve():
    """
    Verifies that 'uploader' role:
      1. Can successfully upload invoices (HTTP 201).
      2. Is FORBIDDEN from approving HITL decisions (HTTP 403).
    """
    # 1. Login as uploader
    login_resp = client.post("/api/v1/auth/login", json={
        "email": "uploader@ledgeragent.dev",
        "password": "LedgerAgent@2026"
    })
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Upload invoice with uploader token -> Expect 201 Created
    pdf_bytes = b"%PDF-1.4\nUploader test invoice\n"
    payload = {"file": ("uploader_invoice.pdf", io.BytesIO(pdf_bytes), "application/pdf")}
    upload_resp = client.post("/api/v1/invoices/upload", files=payload, headers=headers)
    assert upload_resp.status_code == 201
    invoice_id = upload_resp.json()["invoice_id"]
    print(f"✅ [Pass] Uploader successfully ingested invoice -> ID: {invoice_id}")

    # 3. Attempt HITL decision as uploader -> Expect 403 Forbidden
    decide_resp = client.post(
        f"/api/v1/approvals/{invoice_id}/decide",
        json={"decision": "APPROVED", "reviewer_user_id": "uploader@ledgeragent.dev"},
        headers=headers
    )
    assert decide_resp.status_code == 403, f"Expected 403 Forbidden for uploader, got {decide_resp.status_code}"
    print("✅ [Pass] Uploader correctly blocked from approving exceptions with 403 Forbidden")


def test_reviewer_can_approve_hitl_exceptions():
    """Verifies that 'reviewer' role can successfully approve HITL exception invoices (HTTP 200)."""
    # 1. Login as reviewer
    login_resp = client.post("/api/v1/auth/login", json={
        "email": "reviewer@ledgeragent.dev",
        "password": "LedgerAgent@2026"
    })
    assert login_resp.status_code == 200
    reviewer_token = login_resp.json()["access_token"]
    reviewer_headers = {"Authorization": f"Bearer {reviewer_token}"}

    # 2. Upload an exception invoice
    pdf_bytes = b"%PDF-1.4\nReviewer exception test\n"
    payload = {"file": ("review_test.pdf", io.BytesIO(pdf_bytes), "application/pdf")}
    upload_resp = client.post("/api/v1/invoices/upload", files=payload, headers=reviewer_headers)
    assert upload_resp.status_code == 201
    invoice_id = upload_resp.json()["invoice_id"]

    # 3. Approve as reviewer -> Expect 200 OK
    decide_resp = client.post(
        f"/api/v1/approvals/{invoice_id}/decide",
        json={"decision": "APPROVED", "reviewer_user_id": "reviewer@ledgeragent.dev"},
        headers=reviewer_headers
    )
    assert decide_resp.status_code == 200
    data = decide_resp.json()
    assert data["status"] == "GL_POSTED"
    print(f"✅ [Pass] Reviewer successfully approved exception and posted to GL -> Ref: {data['gl_reference_id']}")


def test_security_headers_present_on_responses():
    """Verifies that security headers (nosniff, DENY, CSP) are present on all responses."""
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.headers.get("X-Content-Type-Options") == "nosniff"
    assert resp.headers.get("X-Frame-Options") == "DENY"
    assert resp.headers.get("Referrer-Policy") == "no-referrer"
    assert "Content-Security-Policy" in resp.headers
    print("✅ [Pass] Security headers (nosniff, DENY, CSP) verified on HTTP response")
