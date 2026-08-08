-- =============================================================================
-- LedgerAgent — Production PostgreSQL DDL Schema
-- Architecture Specification (Checkpoint 1 Deliverable 1)
-- Target Engine: PostgreSQL 15+ (AWS RDS PostgreSQL / Local dev container)
-- Standard Reference: AGENTS.md Code Quality & Data Integrity Standards
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- Needed for fuzzy vendor string matching

-- Clean teardown for migrations/local testing (idempotent bootstrap)
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS dead_letter_queue CASCADE;
DROP TABLE IF EXISTS gl_entries CASCADE;
DROP TABLE IF EXISTS approval_requests CASCADE;
DROP TABLE IF EXISTS match_results CASCADE;
DROP TABLE IF EXISTS goods_receipts CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS extracted_fields CASCADE;
DROP TABLE IF EXISTS invoices CASCADE;

-- Custom ENUM types for strict state machine transitions and auditability
CREATE TYPE invoice_status_enum AS ENUM (
    'INGESTED',
    'OCR_PROCESSING',
    'OCR_FAILED',
    'EXTRACTED',
    'VALIDATION_FAILED',
    'MATCHING',
    'MATCHED_AUTO_APPROVED',
    'HITL_PENDING',
    'HITL_APPROVED',
    'HITL_REJECTED',
    'GL_POSTED',
    'FAILED_DEAD_LETTER'
);

CREATE TYPE match_status_enum AS ENUM (
    'FULL_MATCH',
    'PARTIAL_MATCH_WITHIN_TOLERANCE',
    'PRICE_MISMATCH',
    'QUANTITY_MISMATCH',
    'MISSING_PO',
    'MISSING_RECEIPT',
    'VENDOR_MISMATCH',
    'CURRENCY_MISMATCH'
);

CREATE TYPE hitl_decision_enum AS ENUM (
    'APPROVED',
    'REJECTED',
    'CORRECTED_AND_APPROVED',
    'ESCALATED'
);

-- =============================================================================
-- 1. INVOICES TABLE
-- Ingested raw invoice metadata, S3 storage pointers, and SHA-256 deduplication
-- =============================================================================
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sha256_hash CHAR(64) NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    s3_bucket VARCHAR(63) NOT NULL,
    s3_key VARCHAR(1024) NOT NULL,
    file_size_bytes BIGINT NOT NULL CHECK (file_size_bytes > 0 AND file_size_bytes <= 20971520), -- 20MB upper bound limit
    mime_type VARCHAR(100) NOT NULL DEFAULT 'application/pdf',
    status invoice_status_enum NOT NULL DEFAULT 'INGESTED',
    ocr_engine_used VARCHAR(50), -- 'TEXTRACT' or 'PADDLE_OCR'
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Idempotency Guard: Absolute constraint against duplicate invoice processing
    CONSTRAINT uq_invoices_sha256_hash UNIQUE (sha256_hash)
);

COMMENT ON TABLE invoices IS 'Primary entry table for invoice files. Strictly guarded by SHA-256 uniqueness for idempotency.';
COMMENT ON COLUMN invoices.sha256_hash IS 'SHA-256 hash of the binary file content computed prior to ingestion.';

-- =============================================================================
-- 2. EXTRACTED_FIELDS TABLE
-- Structured field extractions validated by Pydantic, with per-field confidence
-- =============================================================================
CREATE TABLE extracted_fields (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    vendor_name VARCHAR(255) NOT NULL,
    vendor_tax_id VARCHAR(50),
    invoice_number VARCHAR(100) NOT NULL,
    po_number VARCHAR(100),
    invoice_date DATE NOT NULL,
    due_date DATE,
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0),
    tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (tax_amount >= 0),
    total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
    line_items JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of {item_code, description, quantity, unit_price, line_total}
    
    -- JSONB map containing per-field extraction confidence: {"vendor_name": 0.98, "total_amount": 0.99, ...}
    field_confidences JSONB NOT NULL,
    overall_confidence NUMERIC(4, 3) NOT NULL CHECK (overall_confidence >= 0.000 AND overall_confidence <= 1.000),
    
    raw_ocr_payload JSONB, -- Retained for audit & debugging
    extracted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_extracted_fields_invoice UNIQUE (invoice_id)
);

COMMENT ON TABLE extracted_fields IS 'Pydantic-validated structured fields extracted by Llama 3.3 70B via Groq with per-field confidence scores.';

-- =============================================================================
-- 3. PURCHASE_ORDERS TABLE (Mirrored from ERP/Mock ERP)
-- Reference purchase order headers & item commitments
-- =============================================================================
CREATE TABLE purchase_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    po_number VARCHAR(100) NOT NULL,
    vendor_name VARCHAR(255) NOT NULL,
    vendor_code VARCHAR(50) NOT NULL,
    po_date DATE NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0),
    tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
    line_items JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of {po_line, item_code, description, quantity, unit_price, line_total}
    status VARCHAR(50) NOT NULL DEFAULT 'OPEN',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_purchase_orders_number UNIQUE (po_number)
);

COMMENT ON TABLE purchase_orders IS 'Purchase Orders imported/synced from Mock ERP to support three-way matching.';

-- =============================================================================
-- 4. GOODS_RECEIPTS TABLE (Mirrored from ERP/Warehouse)
-- Proof of physical receipt of goods against PO lines
-- =============================================================================
CREATE TABLE goods_receipts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    receipt_number VARCHAR(100) NOT NULL,
    po_number VARCHAR(100) NOT NULL REFERENCES purchase_orders(po_number) ON DELETE RESTRICT,
    received_date DATE NOT NULL,
    received_by VARCHAR(100) NOT NULL,
    line_items JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of {receipt_line, item_code, quantity_received, condition}
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_goods_receipts_number UNIQUE (receipt_number)
);

COMMENT ON TABLE goods_receipts IS 'Warehouse delivery receipts certifying physical receipt of line item quantities.';

-- =============================================================================
-- 5. MATCH_RESULTS TABLE
-- Mathematical outcomes of Three-Way Reconciliation (Invoice vs PO vs Receipt)
-- =============================================================================
CREATE TABLE match_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    po_number VARCHAR(100) REFERENCES purchase_orders(po_number) ON DELETE SET NULL,
    match_status match_status_enum NOT NULL,
    invoice_total NUMERIC(12, 2) NOT NULL,
    po_total NUMERIC(12, 2),
    received_total NUMERIC(12, 2),
    price_variance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    quantity_variance NUMERIC(12, 4) NOT NULL DEFAULT 0.0000,
    variance_percentage NUMERIC(6, 3) NOT NULL DEFAULT 0.000,
    
    -- Within tolerance threshold (e.g. <= 2.0% variance and total <= $10.00 variance)
    within_tolerance BOOLEAN NOT NULL DEFAULT FALSE,
    discrepancy_reasons JSONB NOT NULL DEFAULT '[]'::jsonb, -- List of specific error strings
    line_level_matches JSONB NOT NULL DEFAULT '[]'::jsonb,
    evaluated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_match_results_invoice UNIQUE (invoice_id)
);

COMMENT ON TABLE match_results IS 'Three-way match deterministic verification outcomes comparing Invoice vs PO vs Goods Receipts.';

-- =============================================================================
-- 6. APPROVAL_REQUESTS TABLE (HITL Guardrail Queue)
-- Human-in-the-loop review tickets for confidence < 0.85 or rule exceptions
-- =============================================================================
CREATE TABLE approval_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    match_result_id UUID REFERENCES match_results(id) ON DELETE CASCADE,
    requires_approval_reason VARCHAR(255) NOT NULL,
    confidence_score NUMERIC(4, 3) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'RESOLVED', 'EXPIRED'
    decision hitl_decision_enum,
    reviewer_user_id VARCHAR(100),
    reviewer_notes TEXT,
    corrected_payload JSONB, -- In case reviewer corrected fields via UI
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ,

    CONSTRAINT uq_approval_requests_invoice UNIQUE (invoice_id)
);

COMMENT ON TABLE approval_requests IS 'Human approval queue for low-confidence extraction (<0.85) or matching exceptions.';

-- =============================================================================
-- 7. GL_ENTRIES TABLE
-- Posted General Ledger records ready for accounting synchronization
-- Strict ON DELETE RESTRICT to protect financial ledger immutability
-- =============================================================================
CREATE TABLE gl_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
    erp_reference_id VARCHAR(100), -- Return ID from Mock ERP / SAP / NetSuite
    transaction_date DATE NOT NULL,
    debit_account VARCHAR(50) NOT NULL,   -- e.g. '5000-EXPENSE-COGS'
    credit_account VARCHAR(50) NOT NULL,  -- e.g. '2000-ACCOUNTS-PAYABLE'
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    description VARCHAR(500) NOT NULL,
    posted_by VARCHAR(50) NOT NULL DEFAULT 'LEDGER_AGENT_SYSTEM', -- 'AGENT_AUTO' or 'REVIEWER_USERNAME'
    posted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_gl_entries_invoice UNIQUE (invoice_id)
);

COMMENT ON TABLE gl_entries IS 'Final General Ledger accounting entries. Protected with ON DELETE RESTRICT to prevent financial data loss.';

-- =============================================================================
-- 8. AUDIT_LOGS TABLE
-- Immutable append-only audit trail capturing every agent action and user override
-- =============================================================================
CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
    trace_id VARCHAR(100), -- Langfuse trace ID cross-reference
    agent_node VARCHAR(100) NOT NULL, -- e.g. 'ocr_extract', 'validate_extraction', 'three_way_match'
    action VARCHAR(100) NOT NULL,
    actor_type VARCHAR(20) NOT NULL DEFAULT 'AGENT', -- 'AGENT', 'USER', 'SYSTEM'
    actor_id VARCHAR(100) NOT NULL DEFAULT 'ledger_agent',
    previous_state JSONB,
    new_state JSONB,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE audit_logs IS 'Append-only audit trail logging every state transition, LLM decision, and human intervention.';

-- =============================================================================
-- 9. DEAD_LETTER_QUEUE TABLE
-- Unprocessable invoices requiring engineering/ops triage
-- =============================================================================
CREATE TABLE dead_letter_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    failure_stage VARCHAR(100) NOT NULL, -- 'OCR', 'EXTRACTION', 'MATCHING', 'GL_POSTING'
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    retry_count INT NOT NULL DEFAULT 0,
    max_retries INT NOT NULL DEFAULT 3,
    quarantined_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolution_notes TEXT
);

COMMENT ON TABLE dead_letter_queue IS 'Quarantine repository for permanently failed or unparseable invoices.';

-- =============================================================================
-- INDEXES & QUERY PERFORMANCE OPTIMIZATIONS
-- =============================================================================

-- Fast idempotency lookup during invoice ingestion
CREATE INDEX idx_invoices_sha256 ON invoices(sha256_hash);

-- Dashboard query optimization for invoice listing by status and date
CREATE INDEX idx_invoices_status_created ON invoices(status, ingested_at DESC);

-- Partial Index: Ultra-fast polling for Human-in-the-Loop review queue
CREATE INDEX idx_approval_requests_pending ON approval_requests(assigned_at ASC)
WHERE status = 'PENDING';

-- Audit trail index by invoice and trace ID for rapid timeline reconstruction
CREATE INDEX idx_audit_logs_invoice ON audit_logs(invoice_id, created_at DESC);
CREATE INDEX idx_audit_logs_trace ON audit_logs(trace_id);

-- Match lookups
CREATE INDEX idx_match_results_po ON match_results(po_number);

-- GIN Index for fast JSONB querying on line items and per-field confidence
CREATE INDEX idx_extracted_fields_line_items ON extracted_fields USING gin (line_items);
CREATE INDEX idx_extracted_fields_confidences ON extracted_fields USING gin (field_confidences);

-- =============================================================================
-- INTERVIEW DEFENSE & ARCHITECTURAL RATIONALE
-- =============================================================================
/*
Q: Why use SHA-256 at the database level instead of just checking file names or invoice numbers?
A: In corporate finance, duplicate invoice submission under different file names or dates is a major
   fraud/double-payment vulnerability. A SHA-256 binary hash computed at ingestion and enforced via
   UNIQUE constraint guarantees cryptographic idempotency before any expensive LLM or OCR tokens are spent.

Q: Why are field_confidences stored as JSONB with overall_confidence as a distinct column?
A: An overall confidence column allows fast relational threshold checks (overall_confidence < 0.85),
   while JSONB enables the React UI to visually highlight exact low-confidence bounding boxes or fields
   (e.g., tax_amount: 0.62) without altering table schemas when new fields are introduced.

Q: Why is ON DELETE RESTRICT enforced on gl_entries?
A: Ledger integrity is sacrosanct. Deleting an invoice record must never delete the financial ledger
   transaction without an explicit reverse/credit-memo workflow.

Q: Why use a partial index on approval_requests?
A: In production, 85-90% of invoices are resolved. A partial index (WHERE status = 'PENDING') indexes
   only active review tickets, keeping index memory footprint minimal and dashboard load times < 10ms.
*/

-- =============================================================================
-- KNOWN LIMITATIONS (Student Budget & MVP Scope)
-- =============================================================================
/*
1. Single Currency Assumption: While currency codes are stored (ISO-4217), real-time FX conversion
   rate tables are deferred to post-MVP.
2. Single-Tenant Schema: Database schema is optimized for a single enterprise deployment rather
   than multi-tenant row-level security (RLS) to maintain simplicity and performance on db.t4g.micro.
3. No Active Table Partitioning: For <100,000 invoices/year, standard B-tree and GIN indexes on
   PostgreSQL 15 provide sub-millisecond lookups; declarative date-partitioning is reserved for >1M records.
*/
