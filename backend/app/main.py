"""
LedgerAgent — Core FastAPI Application Entrypoint (Hardened Security Mode)
=============================================================================
Module: backend/app/main.py
Standards Reference: AGENTS.md Security Audit & RBAC Infrastructure
=============================================================================
"""

import os
import time
from collections import defaultdict
from typing import Dict, List
from fastapi import FastAPI, Request, Response, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import logging

from backend.app.api.routes import router as invoice_router
from backend.app.api.auth_routes import router as auth_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("ledgeragent.main")

app = FastAPI(
    title="LedgerAgent — Hardened Agentic Reconciliation API",
    version="2.0.0",
    description="Enterprise accounts-payable agent with JWT authentication, granular RBAC, and rate limiting."
)


# =============================================================================
# 1. SECURITY HEADERS MIDDLEWARE (nosniff, DENY frame, CSP)
# =============================================================================
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response: Response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "
        "script-src 'self' 'unsafe-inline'; "
        "style-src 'self' 'unsafe-inline'; "
        "font-src 'self' data:; "
        "img-src 'self' data:; "
        "connect-src 'self' http://localhost:8000 http://localhost:8001 http://127.0.0.1:8000 http://127.0.0.1:8001 http://localhost:5173 http://127.0.0.1:5173;"
    )
    return response


# =============================================================================
# 2. IN-MEMORY RATE LIMITER MIDDLEWARE (5 req/min login, 20 req/min upload)
# =============================================================================
RATE_LIMIT_STORE: Dict[str, List[float]] = defaultdict(list)

@app.middleware("http")
async def rate_limiting_middleware(request: Request, call_next):
    client_ip = request.client.host if request.client else "unknown"
    path = request.url.path
    now = time.time()

    # Rule: 5 req/min for auth login
    if path == "/api/v1/auth/login" and request.method == "POST":
        key = f"login_{client_ip}"
        RATE_LIMIT_STORE[key] = [t for t in RATE_LIMIT_STORE[key] if now - t < 60.0]
        if len(RATE_LIMIT_STORE[key]) >= 5:
            return JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                content={"detail": "Rate limit exceeded: Maximum 5 login attempts per minute. Please wait."}
            )
        RATE_LIMIT_STORE[key].append(now)

    # Rule: 20 req/min for invoice upload
    elif path == "/api/v1/invoices/upload" and request.method == "POST":
        key = f"upload_{client_ip}"
        RATE_LIMIT_STORE[key] = [t for t in RATE_LIMIT_STORE[key] if now - t < 60.0]
        if len(RATE_LIMIT_STORE[key]) >= 20:
            return JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                content={"detail": "Rate limit exceeded: Maximum 20 invoice uploads per minute. Please throttle."}
            )
        RATE_LIMIT_STORE[key].append(now)

    return await call_next(request)


# =============================================================================
# 3. STRICT CORS CONFIGURATION (No Wildcard)
# =============================================================================
allowed_origins_env = os.getenv("ALLOWED_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173")
origins_list = [o.strip() for o in allowed_origins_env.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["Content-Length", "X-Total-Count"]
)


# =============================================================================
# 4. GLOBAL EXCEPTION HANDLER
# =============================================================================
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Global unhandled exception on {request.method} {request.url.path}: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": str(exc),
            "type": type(exc).__name__,
            "path": request.url.path
        }
    )


# =============================================================================
# 5. HEALTH REPORT (Root /health)
# =============================================================================
@app.get("/health", tags=["Health"])
def health_check():
    import httpx
    mock_erp_url = os.getenv("MOCK_ERP_URL", "http://localhost:8001")
    erp_status = "down"
    try:
        with httpx.Client(timeout=1.0) as client:
            resp = client.get(f"{mock_erp_url}/health", headers={"User-Agent": "LedgerAgent/1.0"})
            if resp.status_code == 200:
                erp_status = "up"
    except Exception:
        erp_status = "down"

    return {
        "status": "HEALTHY",
        "service": "LedgerAgent Backend Core",
        "security": "Hardened JWT RBAC Active",
        "dependencies": {
            "mock_erp": erp_status,
            "mock_erp_url": mock_erp_url,
            "postgres": "up" if os.getenv("DATABASE_URL") else "in-memory",
            "redis": "up" if os.getenv("REDIS_URL") else "memory-checkpointer"
        }
    }


# =============================================================================
# 6. ROUTE MOUNTING
# =============================================================================
app.include_router(auth_router)
app.include_router(invoice_router)
