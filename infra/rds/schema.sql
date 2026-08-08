-- =============================================================================
-- LedgerAgent — Authoritative PostgreSQL 16 Schema Definition
-- Database: ledgeragent
-- Exact 1:1 Mirror of SQLAlchemy ORM Models (backend/app/models/db.py)
-- =============================================================================

-- Enable UUID extension if required
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USERS & RBAC TABLE
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'uploader',
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_users_email ON users(email);

-- 2. INVOICES TABLE
CREATE TABLE IF NOT EXISTS invoices (
    id VARCHAR(36) PRIMARY KEY,
    sha256_hash VARCHAR(64) UNIQUE NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    vendor_name VARCHAR(255),
    invoice_number VARCHAR(100),
    po_number VARCHAR(100),
    total_amount DOUBLE PRECISION,
    subtotal DOUBLE PRECISION,
    tax_amount DOUBLE PRECISION DEFAULT 0.0,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(50) NOT NULL DEFAULT 'INGESTED',
    overall_confidence DOUBLE PRECISION,
    match_status VARCHAR(50),
    requires_hitl BOOLEAN DEFAULT FALSE,
    gl_reference_id VARCHAR(100),
    error_message TEXT,
    raw_ocr_text TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_invoices_sha256_hash ON invoices(sha256_hash);

-- 3. EXTRACTED FIELDS TABLE
CREATE TABLE IF NOT EXISTS extracted_fields (
    id VARCHAR(36) PRIMARY KEY,
    invoice_id VARCHAR(36) UNIQUE NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    vendor_name VARCHAR(255) NOT NULL,
    vendor_tax_id VARCHAR(50),
    invoice_number VARCHAR(100) NOT NULL,
    po_number VARCHAR(100),
    invoice_date VARCHAR(20),
    due_date VARCHAR(20),
    subtotal DOUBLE PRECISION NOT NULL,
    tax_amount DOUBLE PRECISION DEFAULT 0.0,
    total_amount DOUBLE PRECISION NOT NULL,
    line_items JSONB DEFAULT '[]'::jsonb,
    field_confidences JSONB DEFAULT '{}'::jsonb,
    overall_confidence DOUBLE PRECISION NOT NULL,
    extracted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. PURCHASE ORDERS TABLE (ERP Master)
CREATE TABLE IF NOT EXISTS purchase_orders (
    po_number VARCHAR(100) PRIMARY KEY,
    vendor_name VARCHAR(255) NOT NULL,
    vendor_code VARCHAR(50) NOT NULL,
    po_date VARCHAR(20) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    subtotal DOUBLE PRECISION NOT NULL,
    tax_amount DOUBLE PRECISION DEFAULT 0.0,
    total_amount DOUBLE PRECISION NOT NULL,
    line_items JSONB DEFAULT '[]'::jsonb,
    status VARCHAR(50) DEFAULT 'OPEN',
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. GOODS RECEIPTS TABLE (Warehouse Deliveries)
CREATE TABLE IF NOT EXISTS goods_receipts (
    receipt_number VARCHAR(100) PRIMARY KEY,
    po_number VARCHAR(100) NOT NULL REFERENCES purchase_orders(po_number),
    received_date VARCHAR(20) NOT NULL,
    received_by VARCHAR(100) NOT NULL,
    line_items JSONB DEFAULT '[]'::jsonb,
    notes TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. MATCH RESULTS TABLE (3-Way Comparator)
CREATE TABLE IF NOT EXISTS match_results (
    id VARCHAR(36) PRIMARY KEY,
    invoice_id VARCHAR(36) UNIQUE NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    po_number VARCHAR(100),
    match_status VARCHAR(50) NOT NULL,
    invoice_total DOUBLE PRECISION NOT NULL,
    po_total DOUBLE PRECISION,
    received_total DOUBLE PRECISION,
    price_variance DOUBLE PRECISION DEFAULT 0.0,
    quantity_variance DOUBLE PRECISION DEFAULT 0.0,
    variance_percentage DOUBLE PRECISION DEFAULT 0.0,
    within_tolerance BOOLEAN DEFAULT FALSE,
    discrepancy_reasons JSONB DEFAULT '[]'::jsonb,
    line_level_matches JSONB DEFAULT '[]'::jsonb,
    evaluated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. APPROVAL REQUESTS TABLE (HITL Guardrail Queue)
CREATE TABLE IF NOT EXISTS approval_requests (
    id VARCHAR(36) PRIMARY KEY,
    invoice_id VARCHAR(36) UNIQUE NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    requires_approval_reason VARCHAR(255) NOT NULL,
    confidence_score DOUBLE PRECISION NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDING',
    decision VARCHAR(50),
    reviewer_user_id VARCHAR(100),
    reviewer_notes TEXT,
    assigned_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITHOUT TIME ZONE
);
CREATE INDEX IF NOT EXISTS ix_approval_requests_status ON approval_requests(status);

-- 8. GENERAL LEDGER ENTRIES TABLE (Double-Entry Journal)
CREATE TABLE IF NOT EXISTS gl_entries (
    gl_reference_id VARCHAR(100) PRIMARY KEY,
    invoice_id VARCHAR(36) UNIQUE NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
    po_number VARCHAR(100),
    vendor_code VARCHAR(50) NOT NULL DEFAULT 'VEND-00104',
    vendor_name VARCHAR(255) NOT NULL DEFAULT 'Apex Cloud Solutions LLC',
    transaction_date VARCHAR(20) NOT NULL,
    debit_account VARCHAR(50) NOT NULL DEFAULT '5000-EXPENSE-COGS',
    credit_account VARCHAR(50) NOT NULL DEFAULT '2000-ACCOUNTS-PAYABLE',
    amount DOUBLE PRECISION NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    description VARCHAR(500) NOT NULL,
    posted_by VARCHAR(100) NOT NULL DEFAULT 'AGENT_AUTO_STP',
    posted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 9. AUDIT LOGS TABLE (Immutable Event Stream)
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    invoice_id VARCHAR(36) REFERENCES invoices(id) ON DELETE CASCADE,
    trace_id VARCHAR(100),
    agent_node VARCHAR(100) NOT NULL DEFAULT 'system',
    actor VARCHAR(100) NOT NULL DEFAULT 'ledger_agent',
    action VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'VALIDATED',
    details TEXT,
    metadata_json JSONB DEFAULT '{}'::jsonb,
    timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
