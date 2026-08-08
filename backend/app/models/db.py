"""
LedgerAgent — SQLAlchemy 2.0 ORM Models & Durable Persistence Engine
=============================================================================
Module: backend/app/models/db.py
Standards Reference: AGENTS.md Checkpoint 1 PostgreSQL Schema & Checkpoint 6.5 Persistence
=============================================================================
"""

import os
import uuid
import datetime
from typing import Optional, List, Dict, Any
from sqlalchemy import (
    create_engine,
    Column,
    String,
    Float,
    Integer,
    Boolean,
    DateTime,
    Date,
    Text,
    JSON,
    ForeignKey,
    Index
)
from sqlalchemy.orm import declarative_base, sessionmaker, relationship, Session
import bcrypt

# Database Connection: PostgreSQL in production, local SQLite fallback
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./ledgeragent.db")

connect_args = {}
if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(DATABASE_URL, connect_args=connect_args, echo=False)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


# =============================================================================
# 1. ORM TABLE DEFINITIONS
# =============================================================================

class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(50), nullable=False, default="uploader")  # 'uploader', 'reviewer', 'admin'
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)


class Invoice(Base):
    __tablename__ = "invoices"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    sha256_hash = Column(String(64), unique=True, nullable=False, index=True)
    original_filename = Column(String(255), nullable=False)
    vendor_name = Column(String(255), nullable=True)
    invoice_number = Column(String(100), nullable=True)
    po_number = Column(String(100), nullable=True)
    total_amount = Column(Float, nullable=True)
    subtotal = Column(Float, nullable=True)
    tax_amount = Column(Float, nullable=True, default=0.0)
    currency = Column(String(3), default="USD")
    status = Column(String(50), nullable=False, default="INGESTED")  # INGESTED, HITL_PENDING, GL_POSTED, REJECTED
    overall_confidence = Column(Float, nullable=True)
    match_status = Column(String(50), nullable=True)
    requires_hitl = Column(Boolean, default=False)
    gl_reference_id = Column(String(100), nullable=True)
    error_message = Column(Text, nullable=True)
    raw_ocr_text = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    # Relationships
    extracted_fields = relationship("ExtractedField", back_populates="invoice", uselist=False, cascade="all, delete-orphan")
    match_result = relationship("MatchResult", back_populates="invoice", uselist=False, cascade="all, delete-orphan")
    approval_request = relationship("ApprovalRequest", back_populates="invoice", uselist=False, cascade="all, delete-orphan")
    gl_entry = relationship("GLEntry", back_populates="invoice", uselist=False)
    audit_logs = relationship("AuditLog", back_populates="invoice", cascade="all, delete-orphan")


class ExtractedField(Base):
    __tablename__ = "extracted_fields"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    invoice_id = Column(String(36), ForeignKey("invoices.id"), unique=True, nullable=False)
    vendor_name = Column(String(255), nullable=False)
    vendor_tax_id = Column(String(50), nullable=True)
    invoice_number = Column(String(100), nullable=False)
    po_number = Column(String(100), nullable=True)
    invoice_date = Column(String(20), nullable=True)
    due_date = Column(String(20), nullable=True)
    subtotal = Column(Float, nullable=False)
    tax_amount = Column(Float, default=0.0)
    total_amount = Column(Float, nullable=False)
    line_items = Column(JSON, default=list)
    field_confidences = Column(JSON, default=dict)
    overall_confidence = Column(Float, nullable=False)
    extracted_at = Column(DateTime, default=datetime.datetime.utcnow)

    invoice = relationship("Invoice", back_populates="extracted_fields")


class PurchaseOrder(Base):
    __tablename__ = "purchase_orders"

    po_number = Column(String(100), primary_key=True)
    vendor_name = Column(String(255), nullable=False)
    vendor_code = Column(String(50), nullable=False)
    po_date = Column(String(20), nullable=False)
    currency = Column(String(3), default="USD")
    subtotal = Column(Float, nullable=False)
    tax_amount = Column(Float, default=0.0)
    total_amount = Column(Float, nullable=False)
    line_items = Column(JSON, default=list)
    status = Column(String(50), default="OPEN")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)


class GoodsReceipt(Base):
    __tablename__ = "goods_receipts"

    receipt_number = Column(String(100), primary_key=True)
    po_number = Column(String(100), ForeignKey("purchase_orders.po_number"), nullable=False)
    received_date = Column(String(20), nullable=False)
    received_by = Column(String(100), nullable=False)
    line_items = Column(JSON, default=list)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)


class MatchResult(Base):
    __tablename__ = "match_results"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    invoice_id = Column(String(36), ForeignKey("invoices.id"), unique=True, nullable=False)
    po_number = Column(String(100), nullable=True)
    match_status = Column(String(50), nullable=False)
    invoice_total = Column(Float, nullable=False)
    po_total = Column(Float, nullable=True)
    received_total = Column(Float, nullable=True)
    price_variance = Column(Float, default=0.0)
    quantity_variance = Column(Float, default=0.0)
    variance_percentage = Column(Float, default=0.0)
    within_tolerance = Column(Boolean, default=False)
    discrepancy_reasons = Column(JSON, default=list)
    line_level_matches = Column(JSON, default=list)
    evaluated_at = Column(DateTime, default=datetime.datetime.utcnow)

    invoice = relationship("Invoice", back_populates="match_result")


class ApprovalRequest(Base):
    __tablename__ = "approval_requests"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    invoice_id = Column(String(36), ForeignKey("invoices.id"), unique=True, nullable=False)
    requires_approval_reason = Column(String(255), nullable=False)
    confidence_score = Column(Float, nullable=False)
    status = Column(String(50), default="PENDING", index=True)  # PENDING, RESOLVED, EXPIRED
    decision = Column(String(50), nullable=True)
    reviewer_user_id = Column(String(100), nullable=True)
    reviewer_notes = Column(Text, nullable=True)
    assigned_at = Column(DateTime, default=datetime.datetime.utcnow)
    resolved_at = Column(DateTime, nullable=True)

    invoice = relationship("Invoice", back_populates="approval_request")


class GLEntry(Base):
    __tablename__ = "gl_entries"

    gl_reference_id = Column(String(100), primary_key=True)
    invoice_id = Column(String(36), ForeignKey("invoices.id"), unique=True, nullable=False)
    po_number = Column(String(100), nullable=True)
    vendor_code = Column(String(50), nullable=False, default="VEND-00104")
    vendor_name = Column(String(255), nullable=False, default="Apex Cloud Solutions LLC")
    transaction_date = Column(String(20), nullable=False)
    debit_account = Column(String(50), nullable=False, default="5000-EXPENSE-COGS")
    credit_account = Column(String(50), nullable=False, default="2000-ACCOUNTS-PAYABLE")
    amount = Column(Float, nullable=False)
    currency = Column(String(3), default="USD")
    description = Column(String(500), nullable=False)
    posted_by = Column(String(100), nullable=False, default="AGENT_AUTO_STP")
    posted_at = Column(DateTime, default=datetime.datetime.utcnow)

    invoice = relationship("Invoice", back_populates="gl_entry")


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    invoice_id = Column(String(36), ForeignKey("invoices.id", ondelete="CASCADE"), nullable=True)
    trace_id = Column(String(100), nullable=True)
    agent_node = Column(String(100), nullable=False, default="system")
    actor = Column(String(100), nullable=False, default="ledger_agent")
    action = Column(String(100), nullable=False)
    status = Column(String(50), nullable=False, default="VALIDATED")
    details = Column(Text, nullable=True)
    metadata_json = Column(JSON, default=dict)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)

    invoice = relationship("Invoice", back_populates="audit_logs")


# =============================================================================
# 2. SESSION DEPENDENCY INJECTION
# =============================================================================

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# =============================================================================
# 3. DATABASE INITIALIZATION & SEEDING HOOKS
# =============================================================================

def hash_pw(password: str) -> str:
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")


def seed_database_defaults():
    """Initializes all database tables and seeds demo users + Mock ERP baseline data if empty."""
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        # 1. Seed Demo Users if empty
        if db.query(User).count() == 0:
            demo_password = os.getenv("DEMO_USER_PASSWORD", "LedgerAgent@2026")
            hashed = hash_pw(demo_password)

            db.add_all([
                User(email="uploader@ledgeragent.dev", password_hash=hashed, role="uploader"),
                User(email="reviewer@ledgeragent.dev", password_hash=hashed, role="reviewer"),
                User(email="admin@ledgeragent.dev", password_hash=hashed, role="admin"),
            ])
            db.commit()
            print(f"🔒 [Durable DB] Seeded 3 RBAC users into {DATABASE_URL}")

        # 2. Seed Mock ERP Purchase Orders if empty
        if db.query(PurchaseOrder).count() == 0:
            po = PurchaseOrder(
                po_number="PO-2026-8891",
                vendor_name="Apex Cloud Solutions LLC",
                vendor_code="VEND-00104",
                po_date="2026-07-15",
                currency="USD",
                subtotal=4500.00,
                tax_amount=360.00,
                total_amount=4860.00,
                line_items=[
                    {
                        "po_line": 1,
                        "item_code": "SRV-CLOUD-01",
                        "description": "Cloud Compute Task Worker (Hours)",
                        "quantity": 100.0,
                        "unit_price": 45.00,
                        "line_total": 4500.00
                    }
                ],
                status="OPEN"
            )
            db.add(po)
            db.commit()

            gr = GoodsReceipt(
                receipt_number="GR-2026-0412",
                po_number="PO-2026-8891",
                received_date="2026-07-20",
                received_by="operations_lead",
                line_items=[
                    {
                        "receipt_line": 1,
                        "item_code": "SRV-CLOUD-01",
                        "quantity_received": 100.0,
                        "condition": "ACCEPTED"
                    }
                ],
                notes="Physical task completion certified by engineering lead."
            )
            db.add(gr)
            db.commit()
            print("📦 [Durable DB] Seeded Mock ERP PO-2026-8891 and GR-2026-0412.")

    except Exception as e:
        print(f"⚠️ [Durable DB Init Warning]: {e}")
        db.rollback()
    finally:
        db.close()


# Automatically initialize on import
seed_database_defaults()
