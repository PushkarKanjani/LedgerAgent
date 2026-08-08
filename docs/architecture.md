# LedgerAgent — System & AWS Deployment Architecture
**Architecture Specification (Checkpoint 1 Deliverable 4)**  
**Target Platform:** AWS ECS Fargate, AWS RDS PostgreSQL, AWS S3, AWS Secrets Manager, Groq Cloud  
**Standard Reference:** AGENTS.md Free-Tier & Guardrail Standards

---

## 1. High-Level System Architecture Diagram

```
                             [ INVOICE PDF UPLOAD ]
                                       │
                                       ▼
                             ┌───────────────────┐
                             │  Amazon S3 Bucket │
                             │ (raw-invoices)    │
                             └─────────┬─────────┘
                                       │ (SHA-256 Hash & Ingest)
                                       ▼
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │                            AWS ECS FARGATE CLUSTER                              │
 │                                                                                 │
 │   ┌────────────────────────┐                   ┌────────────────────────────┐  │
 │   │  React Dashboard (Vite)│                   │   FastAPI + LangGraph      │  │
 │   │  Port 80 (App Runner)  │◄─(REST API / JWT)─┤   Port 8000 (Backend Core) │  │
 │   └────────────────────────┘                   └─────────────┬──────────────┘  │
 │                                                              │                  │
 │   ┌────────────────────────┐                                 │ (Three-Way Match)│
 │   │   Mock ERP Service     │◄────────────────────────────────┘                  │
 │   │   Port 8001 (Internal) │                                                    │
 │   └────────────────────────┘                                                    │
 └─────────────────────────┬────────────────────────────┬──────────────────────────┘
                           │                            │
            (State & Audit)│                            │ (Inference / OCR)
                           ▼                            ▼
                 ┌───────────────────┐        ┌─────────────────────────┐
                 │ Amazon RDS Postgres│        │ Groq Cloud API          │
                 │ db.t4g.micro (Free)│        │ Llama 3.3 70B Versatile │
                 └───────────────────┘        └─────────────────────────┘
                           ▲                            ▲
                           │                            │
                 ┌───────────────────┐        ┌─────────────────────────┐
                 │ ElastiCache Redis │        │ AWS Textract / PaddleOCR│
                 │ cache.t4g.micro   │        │ Primary & Fallback OCR  │
                 └───────────────────┘        └─────────────────────────┘
```

---

## 2. ECS Fargate Task Definition (Cost-Optimized for Student Budget)

```json
{
  "family": "ledger-agent-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/ledgerAgentTaskRole",
  "containerDefinitions": [
    {
      "name": "ledger-backend",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/ledger-agent-backend:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "hostPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "ENVIRONMENT", "value": "production"},
        {"name": "MOCK_ERP_URL", "value": "http://localhost:8001"},
        {"name": "OCR_MONTHLY_LIMIT", "value": "950"}
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:ledger-agent/db-url"
        },
        {
          "name": "GROQ_API_KEY",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:ledger-agent/groq-api-key"
        },
        {
          "name": "LANGFUSE_PUBLIC_KEY",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:ledger-agent/langfuse-pub"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/ledger-agent-backend",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "backend"
        }
      }
    },
    {
      "name": "mock-erp",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/ledger-agent-mock-erp:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8001,
          "hostPort": 8001,
          "protocol": "tcp"
        }
      ]
    }
  ]
}
```

---

## 3. Application Load Balancer (ALB) Routing Topology

- **Public Subnets:**
  - ALB receives external HTTPS traffic on port 443.
  - Path `/api/*` forwards to Backend Target Group (`port 8000`).
  - Path `/*` forwards to Frontend Target Group (`port 80`).

## 6. Durable Persistence & Checkpointer Design Decisions (Phase 6.5)

### Database Layer: SQLAlchemy 2.0 ORM over SQLite & AWS RDS PostgreSQL
1. **Local Development:** Default connection is backed by `sqlite:///./ledgeragent.db` with WAL mode enabled.
2. **Production AWS RDS:** Swappable via `DATABASE_URL=postgresql://user:pass@rds-host:5432/ledgeragent` without modifying any application business logic.
3. **ORM Schema Alignment:** Models in `backend/app/models/db.py` map 1:1 with `infra/rds/schema.sql` (Invoices, ExtractedFields, PurchaseOrders, GoodsReceipts, MatchResults, ApprovalRequests, GLEntries, AuditLogs, Users).

### State Checkpointing: MemorySaver vs. RedisSaver
- **Local Dev Decision:** The state machine uses `MemorySaver` because individual invoice reconciliation executions complete within 0.061s–1.5s, while all completed states, approvals, GL entries, and audit logs are immediately persisted into the durable database tables.
- **Production AWS Deployment Decision:** In the multi-container Docker/AWS ECS phase, `RedisSaver` connecting to Amazon ElastiCache Redis (`cache.t4g.micro`) will be attached to enable distributed thread resumption across multiple autoscaled Fargate tasks.

- **Private Subnets:**
  - ECS Fargate containers run in private subnets with NAT Gateway or VPC Endpoints for S3 / Secrets Manager.
  - Mock ERP service is internal (`localhost:8001` or private service discovery) and never exposed publicly.

---

## 4. S3 Event Trigger → SQS Pipeline (Production Enhancement Path)

```
[ PDF Uploaded to S3 ]
         │
         ▼
[ S3 Event Notification: ObjectCreated:* ]
         │
         ▼
[ Amazon SQS Queue (invoices-processing-queue) ] ───(Dead Letter Queue for 3x poison pills)
         │
         ▼
[ FastAPI Background Worker / ECS Consumer ]
         │ (Compute SHA-256 & Enter LangGraph)
         ▼
[ PostgreSQL DB & LangGraph State Machine ]
```

---

## 5. Free-Tier Budget Map & Monthly Cost Breakdown

| Service | Free-Tier Allocation | LedgerAgent Monthly Consumption | Estimated Cost |
|---|---|---|---|
| **Groq Llama 3.3 70B** | 30 RPM, 12k TPM, 1,000 requests/day | ~100-300 requests/day during development | **$0.00** |
| **AWS Textract** | 1,000 pages/month (12-month free tier) | ~200-500 test invoices/month + PaddleOCR fallback | **$0.00** |
| **AWS RDS PostgreSQL** | 750 hours/month db.t4g.micro / 20 GB SSD | 1 instance running 24/7 | **$0.00** |
| **AWS ECS Fargate** | 750 hours vCPU / month (First 12 months) | Single 0.5 vCPU / 1GB container instance | **$0.00** |
| **Amazon S3** | 5 GB standard storage / 20,000 GET requests | < 500 MB invoice PDFs | **$0.00** |
| **AWS Secrets Manager**| 30-day trial per secret (3 secrets = ~$1.20/mo post-trial)| 3 secrets | **~$1.20** |
| **Langfuse Cloud** | 50,000 observations / month free tier | ~5,000 observations/month | **$0.00** |
| **GitHub Actions** | 2,000 CI/CD minutes / month | ~300 build minutes/month | **$0.00** |
| **Total Estimated Budget** | | | **~$0.00 - $1.50 / month** |

---

## 6. VPC, Subnets & Security Groups Specification

- **VPC CIDR:** `10.0.0.0/16`
  - **Public Subnet 1 (us-east-1a):** `10.0.1.0/24` (ALB)
  - **Public Subnet 2 (us-east-1b):** `10.0.2.0/24` (ALB)
  - **Private App Subnet 1 (us-east-1a):** `10.0.10.0/24` (ECS Fargate)
  - **Private App Subnet 2 (us-east-1b):** `10.0.11.0/24` (ECS Fargate)
  - **Private DB Subnet 1 (us-east-1a):** `10.0.20.0/24` (RDS + ElastiCache)
  - **Private DB Subnet 2 (us-east-1b):** `10.0.21.0/24` (RDS + ElastiCache)

### Security Groups:
1. `sg-alb`: Inbound 80/443 from `0.0.0.0/0`. Outbound to `sg-ecs-backend`.
2. `sg-ecs-backend`: Inbound 8000 only from `sg-alb`. Inbound 8001 from `localhost`. Outbound to `sg-rds` (port 5432) and HTTPS to AWS services.
3. `sg-rds`: Inbound 5432 only from `sg-ecs-backend`. Outbound blocked.

---

## 7. Interview Defense & Architectural Rationale

> **Q: Why multi-container ECS Fargate rather than AWS Lambda for the backend?**  
> **A:** LangGraph state machine workflows with Langfuse tracing and OCR binaries (PaddleOCR) exceed AWS Lambda's cold-start tolerances and 250 MB unzipped package limits. ECS Fargate provides predictable latency, memory isolation, and continuous container execution within the AWS Free Tier.

> **Q: How does the system ensure zero secret leaks in Docker images?**  
> **A:** Docker images use multi-stage builds without `.env` files. Secrets are injected at runtime via ECS Task Definitions pulling directly from AWS Secrets Manager using IAM task execution roles.

---

## 8. Known Limitations (Student Budget & MVP Scope)

1. **Single-AZ RDS Deployment:** Multi-AZ RDS is disabled to stay within the 750 free-tier hours. Automated daily snapshots provide disaster recovery.
2. **NAT Gateway Cost Mitigation:** In production, a NAT Gateway costs ~$32/month. For local and staging dev, VPC endpoints or public subnet assignment with strict Security Groups can be utilized to eliminate NAT costs.
