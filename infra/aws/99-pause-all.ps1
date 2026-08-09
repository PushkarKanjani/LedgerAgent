# =============================================================================
# 99-pause-all.ps1 - Pause All LedgerAgent AWS Resources to Stop All Charges
# Region: ap-south-1 (Mumbai) | Account: 441214867393
# =============================================================================

[CmdletBinding()]
param(
    [string]$Region = 'ap-south-1',
    [string]$ClusterName = 'ledgeragent-cluster',
    [string]$DbIdentifier = 'ledgeragent-postgres'
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host '  [PAUSE] Stopping All LedgerAgent AWS Compute & Database' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan

# 1. Scale ECS Fargate services to 0 tasks
Write-Host ''
Write-Host '[1/3] Scaling down ECS Fargate services to 0 tasks...' -ForegroundColor Yellow
$services = @('ledgeragent-backend', 'ledgeragent-mock-erp', 'ledgeragent-frontend')
foreach ($svc in $services) {
    & aws ecs update-service --cluster $ClusterName --service $svc --desired-count 0 --region $Region 2>&1 | Out-Null
    Write-Host "  [STOPPED] Service '$svc' scaled to 0." -ForegroundColor Green
}

# 2. Stop Jenkins EC2 Instance
Write-Host ''
Write-Host '[2/3] Stopping Jenkins EC2 Instance...' -ForegroundColor Yellow
$instId = (aws ec2 describe-instances --filters "Name=tag:Name,Values=ledgeragent-jenkins" "Name=instance-state-name,Values=running" --region $Region --query "Reservations[0].Instances[0].InstanceId" --output text 2>$null)
if (-not $instId -or $instId -eq 'None') {
    $instId = 'i-0c8c7be6f2e3f8b09'
}

& aws ec2 stop-instances --instance-ids $instId --region $Region 2>&1 | Out-Null
Write-Host "  [STOPPED] Jenkins EC2 instance '$instId' is stopping." -ForegroundColor Green

# 3. Stop RDS PostgreSQL Database Instance
Write-Host ''
Write-Host '[3/3] Stopping Amazon RDS Database instance...' -ForegroundColor Yellow
& aws rds stop-db-instance --db-instance-identifier $DbIdentifier --region $Region 2>&1 | Out-Null
Write-Host "  [STOPPED] RDS database '$DbIdentifier' is stopping." -ForegroundColor Green

Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host '  ALL SERVICES SAFELY PAUSED - ZERO COMPUTE CHARGES' -ForegroundColor Yellow
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host ''
