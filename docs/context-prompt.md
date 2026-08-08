# LedgerAgent — Antigravity Context Prompt

> This file is reference documentation. Paste this into your Antigravity 2.0 context window when starting a new session.

---

**Task:** Build LedgerAgent — a production-grade agentic invoice reconciliation system that ingests PDFs, extracts structured fields via LLM, performs three-way match against a mock ERP, routes low-confidence cases to a human approval dashboard, and posts approved entries to a mock general ledger.

**Project Context:**
- Developer: Pushkar Kanjani | B.Tech ICT 3rd Year | OCI AI Certified
- Existing Skills: Python, FastAPI, React, Docker, AWS (EC2/S3/IAM), PostgreSQL, LangChain, Groq
- Hardware: CPU-only laptop — cloud-native inference only (Groq Llama 3.3 70B, AWS Textract)
- Budget: Student budget — Groq free tier (30 RPM/12k TPM), Textract (1,000 pages/mo), ECS Fargate (750 hrs/mo)
- Timeline: 4-week MVP → 8-week advanced version

**Tech Stack:**
- Backend: Python 3.11, FastAPI, LangGraph + Redis checkpointing
- Frontend: React 18, Vite, TypeScript, Tailwind CSS
- Database: PostgreSQL (RDS), Redis (ElastiCache)
- Deployment: Docker multi-stage → AWS ECS Fargate, ECR, ALB, S3, Textract, Secrets Manager
- Observability: Langfuse (50k obs/mo free)
- Testing: pytest + DeepEval (100-invoice golden dataset)

**Key Design Patterns:**
- Idempotency: SHA-256 hash deduplication before processing
- Dual-Engine OCR: Textract (primary) + PaddleOCR (fallback)
- Structured Output: Pydantic models for ALL LLM calls
- HITL: Confidence < 0.85 OR rule violation → React approval dashboard
- Three-Way Match: Full match (auto-approve), partial ≤ tolerance (soft approve), exception (escalate)

**Vibe Coding Protocol:**
AI agents build rapidly but MUST pause at 5 human guardrail checkpoints:
1. Architecture Review (before scaffolding)
2. Security Audit (before auth/secrets code)
3. State Design (before LangGraph implementation)
4. Cost Check (before AWS provisioning)
5. Production Gate (before deployment)

**First Steps (Manager View, 2 Parallel Agents):**
- Agent 1 (Backend): Scaffold FastAPI + LangGraph (graph.py, nodes.py, tools.py, schemas.py)
- Agent 2 (Frontend): Scaffold React dashboard (InvoiceList, InvoiceDetail, ApprovalView)

**Context Files (Always Include):**
- AGENTS.md
- backend/app/agent/schemas.py
- backend/app/agent/graph.py
- infra/rds/schema.sql

**Constraints:**
- NO local Ollama (CPU-only, 70B too large)
- NO paid-only tools without free/student tiers
- NO enterprise credentials required (mock ERP is sufficient for MVP)

**Start by:**
1. Reading AGENTS.md for project rules and guardrail protocol
2. Creating folder structure (backend/, frontend/, mock_erp/, infra/, tests/, docs/)
3. Scaffolding backend and frontend in parallel
4. Pausing at Checkpoint 1 (Architecture Review) before writing any agent logic
