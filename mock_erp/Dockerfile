# =============================================================================
# Mock ERP Service — Lightweight Slim Container
# Port: 8001 (Simulates SAP / NetSuite endpoints, fast memory footprint)
# =============================================================================

FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install isolated ERP dependencies from binary wheels
RUN pip install --no-cache-dir \
    fastapi==0.110.0 \
    uvicorn==0.28.0 \
    pydantic==2.6.4 \
    sqlalchemy==2.0.28 \
    psycopg2-binary==2.9.9 \
    bcrypt==4.1.2 \
    httpx==0.27.0

# Copy shared DB models and Mock ERP code
COPY backend/app/models /app/backend/app/models
COPY mock_erp/app /app/mock_erp/app

ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

EXPOSE 8001

HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

CMD ["uvicorn", "mock_erp.app.main:app", "--host", "0.0.0.0", "--port", "8001"]
