# AGENTS.md — LedgerAgent Project Rules

**Project:** LedgerAgent  
**Tagline:** Production-grade agentic invoice reconciliation with three-way matching, HITL approval, and durable workflows on AWS ECS Fargate  
**Stage:** MVP (4-week build) → Advanced (8-week polish)  
**Developer:** Pushkar Kanjani | B.Tech ICT Student (3rd Year) | OCI AI Certified  
**Existing Skills:** Python, FastAPI, React, Docker, AWS (EC2/S3/IAM), PostgreSQL, LangChain, Groq  
**Hardware:** CPU-only laptop — cloud-native inference only (Groq, AWS Textract)  
**Budget:** Student budget — free tiers and open-source tooling prioritized  

---

## Tech Stack

- **Backend:** Python 3.11, FastAPI, LangGraph (stateful workflows + Redis checkpointing)
- **Frontend:** React 18, Vite, TypeScript, Tailwind CSS
- **Database:** PostgreSQL (RDS), Redis (ElastiCache for LangGraph checkpoints)
- **Containerization:** Docker (multi-stage builds)
- **Deployment:** AWS ECS Fargate, ECR, ALB, S3, Textract, IAM, Secrets Manager
- **LLM:** Groq-hosted Llama 3.3 70B Versatile (free tier: 30 RPM, 12k TPM, 1k RPD)
- **OCR:** AWS Textract (1,000 pages/month free) + PaddleOCR (fallback)
- **Observability:** Langfuse (50k observations/month free)
- **Testing:** pytest, DeepEval (golden dataset of 100 invoices)

---

## Code Quality Standards

- **Type Safety:** All LLM outputs use Pydantic structured output (no free-text parsing)
- **Idempotency:** SHA-256 hash deduplication on invoice ingestion before processing
- **Error Handling:** Retry-with-backoff on OCR/API failures; dead-letter queue for unprocessable invoices
- **Security:** All secrets in AWS Secrets Manager — never hardcode API keys
- **Logging:** Every agent step logged to Langfuse + PostgreSQL `audit_logs` table
- **HITL Guardrail:** Confidence < 0.85 OR rule violation → mandatory human approval

---

## File Structure Conventions

```
ledger-agent/
├── backend/app/agent/graph.py      # LangGraph state machine
├── backend/app/agent/nodes.py      # Agent nodes (plan, OCR, match, HITL)
├── backend/app/agent/tools.py      # Tool wrappers (Textract, Mock ERP)
├── backend/app/agent/schemas.py    # Pydantic models for structured output
├── mock_erp/app/main.py            # Mock ERP API (vendors, POs, receipts, GL)
├── frontend/src/App.tsx            # React approval dashboard
├── infra/ecs/task-definition.json  # ECS task definition
├── infra/rds/schema.sql            # PostgreSQL schema
├── tests/                          # Unit, integration, eval tests
└── docs/                           # Architecture diagrams, API contracts
```

---

## Testing Requirements

- **Unit Tests:** pytest for agent nodes, API endpoints, OCR wrapper
- **Integration Tests:** End-to-end flow (ingest → extract → match → approve → post)
- **Evals:** DeepEval on golden dataset (100 invoices) — target: field-level F1 > 0.85, invoice-level accuracy > 90%

---

## Git Conventions

- **Branches:** `main` (production), `develop` (integration), `feature/*` branches
- **Commits:** Conventional commits (`feat:`, `fix:`, `chore:`, `docs:`)
- **PRs:** Under 400 lines diff, require passing CI (GitHub Actions, 2,000 min/month free)

---

## Vibe Coding + Human Guardrail Protocol

This project uses AI-assisted rapid development with mandatory human checkpoints:

| Checkpoint | Trigger | Human Action Required |
|---|---|---|
| Architecture Review | Before scaffolding | Approve container/networking design |
| Security Audit | Before auth/secrets code | Review RBAC, input sanitization |
| State Design | Before LangGraph implementation | Confirm checkpoint/persistence strategy |
| Cost Check | Before AWS resource provisioning | Validate free-tier limits |
| Production Gate | Before deployment | Verify observability, idempotency, error handling |

**AI agents MUST pause at each checkpoint and request explicit approval before proceeding.**

---

## Common Pitfalls to Avoid

- ❌ No idempotency → duplicate payments (always hash before processing)
- ❌ Single OCR engine → silent failures (always implement Textract + PaddleOCR fallback)
- ❌ ECS memory overflow → stream large PDFs via S3, cap task at 4 GB
- ❌ Free-tier exhaustion → monitor Textract (1k pages/mo), switch to PaddleOCR when approaching limit
- ❌ Local Ollama inference → CPU-only laptop cannot run 70B models; use Groq exclusively

---

## Interview-Ready Design Choices

Be prepared to defend:
- **Why LangGraph over CrewAI?** → Stateful checkpointing for durable, resumable workflows
- **Why Redis over Temporal?** → Simpler for <1-hour workflows; Temporal is a future upgrade path
- **Why Llama 3.3 70B on Groq?** → 99%+ accuracy at 10x lower cost than GPT-4o; free tier sufficient for dev
- **Why Pydantic structured output?** → Type safety, automatic validation, no regex parsing fragility
- **Why dual-engine OCR?** → Textract handles clean PDFs; PaddleOCR catches scanned/degraded documents
