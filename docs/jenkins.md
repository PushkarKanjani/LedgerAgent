# LedgerAgent — Jenkins CI/CD Automation Guide
**Host Instance:** Amazon EC2 `t2.micro` (Amazon Linux 2023 | AWS Free Tier)  
**Target Cluster:** AWS ECS Fargate `ledgeragent-cluster` (`ap-south-1`)  
**Registry:** Amazon ECR (`441214867393.dkr.ecr.ap-south-1.amazonaws.com`)  

---

## 1. Architecture Overview

```
                      [ GITHUB REPOSITORY ]
                                │
                        (Push to main branch)
                                ▼
               ┌─────────────────────────────────┐
               │  Amazon EC2 (t2.micro)          │
               │  Jenkins LTS CI/CD Controller   │
               └────────────────┬────────────────┘
                                │
   ┌────────────────────────────┼────────────────────────────┐
   ▼                            ▼                            ▼
[ 1. Bandit AST Scan ]  [ 2. Pytest Regression ]   [ 3. Multi-Stage Builds ]
   │                            │                            │
   └────────────────────────────┼────────────────────────────┘
                                │
                                ▼
               ┌─────────────────────────────────┐
               │  Amazon ECR Container Registry  │
               │  Push :${BUILD_NUMBER} & :latest│
               └────────────────┬────────────────┘
                                │
                                ▼
               ┌─────────────────────────────────┐
               │  AWS ECS Fargate Rolling Update │
               │  aws ecs update-service         │
               └────────────────┬────────────────┘
                                │
                                ▼
               ┌─────────────────────────────────┐
               │  Application Load Balancer      │
               │  Poll /api/v1/health until 200  │
               └─────────────────────────────────┘
```

---

## 2. Initial Jenkins Setup & Admin Password

After provisioning the server via `.\infra\aws\09-jenkins.ps1`:

### Step 1: Open the Jenkins Web Console
Navigate in your browser to:
```
http://<JENKINS_PUBLIC_IP>:8080
```
*(Port 8080 is restricted strictly to your public IP via `ledgeragent-jenkins-sg`)*.

### Step 2: Retrieve the Initial Admin Password
Connect via AWS Systems Manager Session Manager (no SSH key needed):
```powershell
aws ssm start-session --target <INSTANCE_ID> --region ap-south-1
```
Once inside the session, display the initial password:
```bash
sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```
Copy the 32-character token into the Jenkins unlock screen.

### Step 3: Install Suggested Plugins & Create Admin User
1. Click **Install Suggested Plugins** (installs Git, Pipeline, Workspace Cleanup, and Build Timeout).
2. Create your administrator account (e.g. `admin` / `LedgerAgent@2026`).

---

## 3. Creating the CI/CD Pipeline Job

1. From the Jenkins dashboard, click **New Item**.
2. Enter Item Name: `ledgeragent-pipeline`.
3. Select **Pipeline** and click **OK**.
4. Scroll to **Build Triggers**:
   - Check **Poll SCM** and enter Schedule:
     ```
     H/5 * * * *
     ```
     *(Polls GitHub every 5 minutes for new commits on main)*.
5. Scroll to **Pipeline**:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/<your-org>/LedgerAgent.git` (or your repo URL)
   - Branches to build: `*/main`
   - Script Path: `Jenkinsfile`
6. Click **Save**.

---

## 4. (Optional) Instant GitHub Webhook Integration

For instant triggers upon git push instead of polling:
1. In your GitHub repository, go to **Settings** → **Webhooks** → **Add webhook**.
2. Payload URL: `http://<JENKINS_PUBLIC_IP>:8080/github-webhook/`
3. Content type: `application/json`
4. Which events: **Just the push event**
5. Click **Add webhook**.

---

## 5. Pipeline Stages & Verification Checklist

| Stage | Action | Verification |
|---|---|---|
| **1. SCM Checkout** | Clones latest commit on `main` branch. | Workspace initialized. |
| **2. Security Scan** | Executes Bandit AST vulnerability inspection. | Flags zero high-severity issues. |
| **3. Pytest Smoke** | Runs isolated persistence & authentication tests. | All unit tests pass. |
| **4. Docker Builds** | Builds 3 containers from repo-root context. | Multi-stage caching applied. |
| **5. ECR Push** | Pushes `:${BUILD_NUMBER}` and `:latest` tags. | Verified in ECR registry console. |
| **6. ECS Rolling Update** | Calls `aws ecs update-service --force-new-deployment`. | Zero-downtime task replacement. |
| **7. Health Verification** | Polls `http://<ALB_DNS>/api/v1/health` until HTTP 200. | Ingress routing operational. |

---

## 6. Monthly Cost Estimation

| Service | Configuration | Monthly Cost |
|---|---|---|
| **EC2 t2.micro** | 750 hours/month AWS Free Tier | **$0.00 / mo** |
| **EBS Storage** | 8 GB gp2 Free Tier | **$0.00 / mo** |
| **Security Ingress** | Restricted to operator IP (`checkip.amazonaws.com`) | **$0.00 / mo** |
| **Total CI/CD Cost** | Dedicated Jenkins Server | **$0.00 / mo** *(100% Free Tier)* |
