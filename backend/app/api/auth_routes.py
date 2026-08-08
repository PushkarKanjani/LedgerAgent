"""
LedgerAgent — Authentication REST Endpoints (Durable DB Mode)
=============================================================================
Module: backend/app/api/auth_routes.py
Standards Reference: AGENTS.md Audit Trail on Auth & JWT Security
=============================================================================
"""

from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy.orm import Session
from datetime import datetime
import uuid

from backend.app.models.db import User as DBUser, AuditLog, get_db
from backend.app.auth import (
    UserOut,
    LoginRequest,
    TokenResponse,
    RefreshRequest,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
    ACCESS_TOKEN_EXPIRE_MINUTES
)

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication & RBAC"])


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    """
    Authenticates a user by email & bcrypt password hash from the database.
    Generates a 30-minute access token and a 7-day refresh token.
    Audits every login success and failure into the durable database.
    """
    user = db.query(DBUser).filter(DBUser.email == payload.email).first()
    trace_id = f"auth_{uuid.uuid4().hex[:10]}"

    if not user or not verify_password(payload.password, user.password_hash):
        # Audit failed login attempt into DB
        db.add(AuditLog(
            invoice_id=None,
            trace_id=trace_id,
            agent_node="auth_service",
            actor="auth_service",
            action="LOGIN_FAILED",
            status="REJECTED",
            details=f"Failed authentication attempt for email: {payload.email}"
        ))
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials. Please verify email and password."
        )

    # Success: Generate JWT access + refresh tokens
    access_token = create_access_token(user)
    refresh_token = create_refresh_token(user)

    # Audit successful login into DB
    db.add(AuditLog(
        invoice_id=None,
        trace_id=trace_id,
        agent_node="auth_service",
        actor="auth_service",
        action="LOGIN_SUCCESS",
        status="SUCCESS",
        details=f"User {user.email} logged in with role [{user.role}]"
    ))
    db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        user=UserOut(
            id=user.id,
            email=user.email,
            role=user.role,
            created_at=user.created_at
        )
    )


@router.post("/refresh")
def refresh_token(payload: RefreshRequest, db: Session = Depends(get_db)):
    """Refreshes an expired access token using a valid refresh token from DB."""
    decoded = decode_token(payload.refresh_token, expected_type="refresh")
    email = decoded.get("email")

    user = db.query(DBUser).filter(DBUser.email == email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User associated with refresh token not found."
        )

    new_access_token = create_access_token(user)
    return {
        "access_token": new_access_token,
        "token_type": "bearer",
        "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60
    }


@router.get("/me", response_model=UserOut)
def get_me(current_user: DBUser = Depends(get_current_user)):
    """Returns the authenticated user profile and active RBAC role from DB."""
    return UserOut(
        id=current_user.id,
        email=current_user.email,
        role=current_user.role,
        created_at=current_user.created_at
    )
