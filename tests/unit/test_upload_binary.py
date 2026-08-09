"""
LedgerAgent — Regression Unit Test: Binary PDF Upload & Serialization Safety
=============================================================================
Module: tests/unit/test_upload_binary.py
Standards Reference: AGENTS.md Zero-Bytes Response Models & Idempotency
=============================================================================
"""

import io
import pytest
from fastapi.testclient import TestClient
from backend.app.main import app

client = TestClient(app)


def test_upload_real_binary_pdf_does_not_crash_serialization():
    """
    Regression Test for PydanticSerializationError:
    Verifies that uploading a real binary PDF (containing raw %PDF bytes)
    successfully returns HTTP 201 and valid JSON without UTF-8 serialization errors.
    """
    # 1. Login to obtain valid JWT token
    login_resp = client.post("/api/v1/auth/login", json={
        "email": "uploader@ledgeragent.dev",
        "password": "LedgerAgent@2026"
    })
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Generate real binary PDF byte content
    pdf_bytes = b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
    
    file_payload = {
        "file": ("test_binary_invoice.pdf", io.BytesIO(pdf_bytes), "application/pdf")
    }

    # 3. Perform POST request to upload endpoint with Auth header
    response = client.post("/api/v1/invoices/upload", files=file_payload, headers=headers)

    # 4. Assert HTTP 201 Created
    assert response.status_code == 201, f"Expected 201 Created, got {response.status_code}: {response.text}"

    # 4. Assert response is valid JSON and contains required JSON-safe fields
    data = response.json()
    assert "invoice_id" in data
    assert "sha256_hash" in data
    assert "status" in data
    assert data["status"] in ["GL_POSTED", "HITL_PENDING", "INGESTED", "OCR_PROCESSING"]
    
    # 5. Assert raw bytes are NEVER leaked into the response payload
    assert "raw_file_bytes" not in data
    assert "workflow_state" not in data or data.get("workflow_state") is None or "raw_file_bytes" not in data["workflow_state"]
    print(f"\n✅ [Regression Test Passed] Uploaded binary PDF -> Status {response.status_code} | ID: {data['invoice_id']}")


def test_health_check_reports_dependency_status():
    """
    Verifies that the /health endpoint returns dependency reports.
    """
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "HEALTHY"
    assert "dependencies" in data
    assert "mock_erp" in data["dependencies"]
    assert "postgres" in data["dependencies"]
    assert "redis" in data["dependencies"]
    print(f"✅ [Health Test Passed] Dependencies: {data['dependencies']}")
