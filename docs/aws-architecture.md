# LedgerAgent — AWS Cloud Infrastructure & Cost Architecture
**Target Region:** `ap-south-1` (Mumbai)  
**AWS Account ID:** `441214867393`  
**Standard:** Student Free-Tier & Zero-Trust Production Security  

---

## 1. Cloud Architecture & Network Topology

```mermaid
flowchart TD
    subgraph PUBLIC_INTERNET["PUBLIC INTERNET (0.0.0.0/0)"]
        CLIENT["🌐 React Frontend / Web Browser"]
        GITHUB["🐙 GitHub Repository (main branch)"]
    end

    subgraph AWS_VPC["AWS VPC (10.0.0.0/16) — ap-south-1"]
        IGW["⚡ Internet Gateway (ledgeragent-igw)"]
        
        subgraph PUBLIC_SUBNETS["Public Subnets (Dual-AZ Ingress: 10.0.1.0/24 & 10.0.2.0/24)"]
            ALB["⚖️ Application Load Balancer (ledgeragent-alb)<br/>Path Routing: / -> Frontend | /api/v1/* -> Backend"]
            JENKINS["🛠️ Jenkins CI/CD Controller<br/>(EC2 t2.micro | Docker-in-Docker)"]
            
            subgraph ECS_CLUSTER["AWS ECS Fargate Cluster (ledgeragent-cluster)"]
                FRONTEND["⚛️ Frontend Service (:80)<br/>(256 CPU / 512 MB)"]
                BACKEND["⚡ Backend Service (:8000)<br/>(512 CPU / 1024 MB)"]
                MOCK_ERP["🏢 Mock ERP Service (:8001)<br/>(256 CPU / 512 MB)"]
            end
        end

        subgraph CLOUD_MAP["AWS Cloud Map Service Discovery (ledgeragent.local)"]
            DNS_BACKEND["backend.ledgeragent.local:8000"]
            DNS_ERP["mock-erp.ledgeragent.local:8001"]
        end

        subgraph PRIVATE_SUBNETS["Private Subnets (Dual-AZ Isolation: 10.0.10.0/24 & 10.0.20.0/24)"]
            RDS["🗄️ Amazon RDS PostgreSQL 16<br/>(db.t3.micro | 20GB gp2)<br/>Security: Inbound 5432 strictly from App-SG"]
        end
    end

    subgraph AWS_MANAGED["AWS Managed Security & Storage Services"]
        ECR["📦 Amazon ECR (3 Repositories with 5-Image Retention)"]
        S3["🪣 Amazon S3 (AES256 Encrypted Bucket: ledgeragent-invoices-441214867393)"]
        SECRETS["🔐 AWS Secrets Manager (ledgeragent/db-url, jwt-secret, groq-api-key)"]
        CW["📜 Amazon CloudWatch Logs (30-Day Retention)"]
        GROQ["🤖 Groq Cloud API (Llama 3.3 70B Structured Output)"]
    end

    GITHUB -->|Poll SCM / Webhook| JENKINS
    JENKINS -->|Build, Tag & Push| ECR
    JENKINS -->|Deploy: update-service| ECS_CLUSTER
    
    CLIENT -->|HTTP :80 Ingress| ALB
    ALB -->|Route /api/v1/*| BACKEND
    ALB -->|Route /* (SPA)| FRONTEND
    BACKEND -->|3-Way Reconciliation via Cloud Map| MOCK_ERP
    BACKEND -->|Durable Persistence| RDS
    MOCK_ERP -->|Master Data Query| RDS
    BACKEND -->|PDF Ingestion Archival| S3
    BACKEND -->|Secret Injection via ARNs| SECRETS
    BACKEND -->|Structured Extraction| GROQ
    BACKEND -->|Telemetry Stream| CW
```

---

## 2. Student Free-Tier Monthly Cost Breakdown

Every component is architected to maximize the 12-Month AWS Free Tier and minimize monthly charges on a student budget.

| AWS Service | Resource Specification | Free Tier Allowance | Estimated Monthly Cost |
|---|---|---|---|
| **Amazon RDS PostgreSQL** | `db.t3.micro` Single-AZ, 20GB `gp2`, backup 7 days | 750 hrs/month (12 mos free) | **$0.00 / mo** *(~$14.50 post-free)* |
| **Amazon EC2 (Jenkins)** | `t2.micro` Linux, 8GB `gp2` EBS | 750 hrs/month (12 mos free) | **$0.00 / mo** *(~$8.50 post-free)* |
| **Amazon VPC & Subnets** | 1 VPC, 4 Subnets, 1 IGW, 4 Security Groups | Always Free | **$0.00 / mo** |
| **Amazon ECR** | 3 private repositories with 5-image lifecycle policy | 500 MB/month free tier | **~$0.10 / mo** |
| **Amazon S3** | `ledgeragent-invoices-441214867393` (90-day lifecycle) | 5 GB storage + 20,000 GETs | **~$0.02 / mo** |
| **AWS Secrets Manager** | `ledgeragent/jwt-secret`, `ledgeragent/groq-api-key`, `db-url` | $0.40 / secret / month | **~$1.20 / mo** |
| **Amazon CloudWatch** | `/ecs/ledgeragent-*` with 30-day retention | 5 GB ingestion free tier | **$0.00 / mo** |
| **AWS ECS Fargate** | 3 Tasks (0.25–0.5 vCPU / 0.5–1 GB memory) | ~$0.012 / vCPU-hour | **~$4.50 – $5.00 / mo** |
| **Application Load Balancer** | Single internet-facing ALB in `ap-south-1` | ~$0.0225 / ALB-hour | **~$16.00 / mo** |
| **Total Estimated AWS Bill** | Full Infrastructure Stack (`ap-south-1`) | — | **~$21.82 / mo** |

---

## 3. As-Built MVP Decisions & Trade-Off Analysis

### 1. No Amazon ElastiCache Redis (MemorySaver Adaptive Fallback)
- **Decision:** In the AWS deployment, `REDIS_URL` is omitted, causing `backend/app/agent/graph.py` to seamlessly fall back to in-memory `MemorySaver`.
- **Rationale:** ElastiCache Redis clusters do not offer a free tier and cost **$15.00 – $22.00 / month**. Because individual invoice reconciliation graph runs complete in **0.061s** and durable states, GL entries, and audit logs are immediately persisted into Amazon RDS PostgreSQL, Redis is unnecessary for student/portfolio operations.
- **Enterprise Upgrade Path:** When scaling to multi-task ECS clusters with multi-day human approval cycles, provision `cache.t4g.micro` and supply `REDIS_URL=redis://elasticache-host:6379/0`.

### 2. Public Subnet Placement with `assignPublicIp=ENABLED` (Zero NAT Gateway Fees)
- **Decision:** ECS Fargate tasks and Jenkins EC2 are placed in public subnets with `assignPublicIp=ENABLED` to pull images from ECR and call AWS APIs directly.
- **Rationale:** An AWS NAT Gateway costs **$32.40 / month** per AZ ($64.80/mo for Dual-AZ) plus data processing fees. By placing Fargate tasks in public subnets and locking down ingress via `App-SG` (which accepts traffic **exclusively from ALB-SG**), we achieve bank-grade zero-trust isolation without paying NAT fees.
- **Enterprise Upgrade Path:** Provision private subnets with Dual-AZ NAT Gateways or AWS PrivateLink Interface Endpoints.

### 3. AWS Cloud Map Private Service Discovery (`ledgeragent.local`)
- **Decision:** Integrated AWS Cloud Map private DNS namespace `ledgeragent.local`.
- **Rationale:** Allows internal microservices to communicate deterministically (`http://mock-erp.ledgeragent.local:8001`) over VPC private IPs without exposing ports to the public internet.

---

## 4. Tiered Zero-Trust Security Model

```
[ PUBLIC INTERNET: 0.0.0.0/0 ]
         │
         ▼ Port 80 / 443 (HTTP/HTTPS)
┌──────────────────────────────────────┐
│  ALB-SG (ledgeragent-alb-sg)         │
└──────────────────┬───────────────────┘
                   │ Port 8000 & 8001
                   ▼ (Source: ALB-SG ONLY)
┌──────────────────────────────────────┐
│  App-SG (ledgeragent-app-sg)         │
│  (ECS Tasks: Backend, Mock ERP)      │
└──────────────────┬───────────────────┘
                   │ Port 5432
                   ▼ (Source: App-SG ONLY)
┌──────────────────────────────────────┐
│  DB-SG (ledgeragent-db-sg)           │
│  (Amazon RDS PostgreSQL 16)          │
└──────────────────────────────────────┘
```

1. **ALB-SG:** Accepts HTTP (80) from public ingress (`0.0.0.0/0`).
2. **App-SG:** Accepts port `8000` (FastAPI) and `8001` (Mock ERP) **strictly and exclusively** from `ALB-SG`. Direct internet access is blocked at the security group level.
3. **DB-SG:** Accepts PostgreSQL port `5432` **strictly and exclusively** from `App-SG`. Direct internet access and load balancer traffic are rejected at the packet level.
4. **Jenkins-SG:** Accepts SSH (22) and Web UI (8080) **strictly and exclusively from the operator's current public IP**.

---

## 5. Complete Execution Guide

Run the scripts in numerical order from your PowerShell terminal:

```powershell
cd c:\MyDrive\LedgerAgent\infra\aws

# Step 0: Validate credentials & generate least-privilege policy
.\00-prereqs.ps1

# Step 1: Provision ECR repositories with image lifecycle policies
.\01-ecr.ps1

# Step 2: Provision VPC, Dual-AZ Subnets & Tiered Security Groups
.\02-network.ps1

# Step 3: Provision Amazon RDS PostgreSQL 16 & Secrets Manager credentials
.\03-rds.ps1

# Step 4: Provision Encrypted S3 Bucket & Application Secrets
.\04-s3-secrets.ps1

# Step 5: Build, Tag & Push Docker Images to Amazon ECR
.\05-push-images.ps1

# Step 6: Provision ECS Fargate Cluster, Task Definitions & Cloud Map
.\06-ecs.ps1

# Step 7: Provision Application Load Balancer & Path-Based Routing
.\07-alb.ps1

# Step 8: End-to-End Verification & Health Inspection
.\08-verify.ps1

# Step 9: Provision Jenkins CI/CD Controller on EC2 t2.micro
.\09-jenkins.ps1
```
