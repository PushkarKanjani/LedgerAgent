"""
LedgerAgent — Authentication & Role-Based Access Control (Durable DB Mode)
=============================================================================
Module: backend/app/auth.py
Standards Reference: AGENTS.md Checkpoint 2 Security Audit & Checkpoint 6.5
=============================================================================
"""

import os
import uuid
import datetime
from typing import Optional, List, Dict, Any
from enum import Enum
import bcrypt
import jwt
from pydantic import BaseModel, EmailStr, Field
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from backend.app.models.db import User as DBUser, SessionLocal, get_db

# Security configuration from environment
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "ledgeragent_jwt_super_secret_enterprise_key_2026_x")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))
BCRYPT_ROUNDS = int(os.getenv("BCRYPT_ROUNDS", "12"))

bearer_scheme = HTTPBearer(auto_error=False)


# =============================================================================
# 1. USER & ROLE MODELS
# =============================================================================

class UserRole(str, Enum):
    UPLOADER = "uploader"
    REVIEWER = "reviewer"
    ADMIN = "admin"


class UserOut(BaseModel):
    id: str
    email: EmailStr
    role: UserRole
    created_at: datetime.datetime


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserOut


class RefreshRequest(BaseModel):
    refresh_token: str


# =============================================================================
# 2. BCRYPT UTILITIES
# =============================================================================

def hash_password(password: str) -> str:
    """Hashes a password using raw bcrypt (zero passlib dependency)."""
    salt = bcrypt.gensalt(rounds=BCRYPT_ROUNDS)
    hashed = bcrypt.hashpw(password.encode("utf-8"), salt)
    return hashed.decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifies a plain password against the stored bcrypt hash."""
    return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))


# =============================================================================
# 3. JWT TOKEN CREATION & VERIFICATION
# =============================================================================

def create_access_token(user: DBUser) -> str:
    expire = datetime.datetime.utcnow() + datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": user.id,
        "email": user.email,
        "role": user.role,
        "type": "access",
        "exp": expire,
        "iat": datetime.datetime.utcnow()
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)


def create_refresh_token(user: DBUser) -> str:
    expire = datetime.datetime.utcnow() + datetime.timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {
        "sub": user.id,
        "email": user.email,
        "role": user.role,
        "type": "refresh",
        "exp": expire,
        "iat": datetime.datetime.utcnow()
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)


def decode_token(token: str, expected_type: str = "access") -> Dict[str, Any]:
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        if payload.get("type") != expected_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid token type: expected '{expected_type}'"
            )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired. Please re-authenticate."
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication token: {str(e)}"
        )


# =============================================================================
# 4. DEPENDENCY INJECTION: GET CURRENT USER & REQUIRE ROLE
# =============================================================================

async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: Session = Depends(get_db)
) -> DBUser:
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication credentials were not provided. Include 'Authorization: Bearer <token>'."
        )

    token = credentials.credentials
    payload = decode_token(token, expected_type="access")
    email = payload.get("email")

    user = db.query(DBUser).filter(DBUser.email == email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account associated with token no longer exists in database."
        )
    return user


def require_role(allowed_roles: List[UserRole]):
    """
    FastAPI dependency enforcing granular Role-Based Access Control (RBAC).
    Returns 401 if unauthenticated, 403 if unauthorized for role.
    """
    async def role_checker(current_user: DBUser = Depends(get_current_user)) -> DBUser:
        user_role = current_user.role
        allowed_values = [r.value if isinstance(r, UserRole) else r for r in allowed_roles]
        if user_role not in allowed_values:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Forbidden: Action requires one of roles: {allowed_values}. Your role is '{user_role}'."
            )
        return current_user

    return role_checker
