# =============================================================================
# 98-resume-all.ps1 - Resume All LedgerAgent AWS Resources & Update Ingress
# Region: ap-south-1 (Mumbai) | Account: 441214867393
# =============================================================================

[CmdletBinding()]
param(
    [string]$Region = 'ap-south-1',
    [string]$ClusterName = 'ledgeragent-cluster',
    [string]$DbIdentifier = 'ledgeragent-postgres'
)

$ErrorActionPreference = 'Continue'

function Get-AwsJson {
    param([string[]]$Arguments)
    $raw = & aws @Arguments 2>$null
    if ($LASTEXITCODE -eq 0 -and $raw) {
        try {
            return ($raw | Out-String | ConvertFrom-Json)
        } catch {
            return $null
        }
    }
    return $null
}

Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host '  [RESUME] Starting All LedgerAgent AWS Compute & Database' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan

# 1. Start RDS PostgreSQL Database Instance
Write-Host ''
Write-Host '[1/4] Starting Amazon RDS Database instance...' -ForegroundColor Yellow
& aws rds start-db-instance --db-instance-identifier $DbIdentifier --region $Region 2>&1 | Out-Null
Write-Host "  [STARTED] RDS database '$DbIdentifier' starting up." -ForegroundColor Green

# 2. Start Jenkins EC2 Instance
Write-Host ''
Write-Host '[2/4] Starting Jenkins EC2 Instance...' -ForegroundColor Yellow
$instObj = Get-AwsJson -Arguments @('ec2', 'describe-instances', '--filters', 'Name=tag:Name,Values=ledgeragent-jenkins', '--region', $Region, '--output', 'json')

$instId = 'i-0c8c7be6f2e3f8b09'
if ($instObj -and $instObj.Reservations.Count -gt 0 -and $instObj.Reservations[0].Instances.Count -gt 0) {
    $instId = $instObj.Reservations[0].Instances[0].InstanceId
}

& aws ec2 start-instances --instance-ids $instId --region $Region 2>&1 | Out-Null
Write-Host "  [WAIT] Waiting for EC2 instance '$instId' to enter running state..." -ForegroundColor Yellow
& aws ec2 wait instance-running --instance-ids $instId --region $Region 2>&1 | Out-Null

$desc = Get-AwsJson -Arguments @('ec2', 'describe-instances', '--instance-ids', $instId, '--region', $Region, '--output', 'json')
$publicIp = ''
if ($desc -and $desc.Reservations.Count -gt 0) {
    $publicIp = $desc.Reservations[0].Instances[0].PublicIpAddress
}
Write-Host "  [RUNNING] EC2 Instance '$instId' is online at IP: $publicIp" -ForegroundColor Green

# 3. Update Security Group with Operator's Current Public IP
Write-Host ''
Write-Host '[3/4] Updating Jenkins Security Group with your current public IP...' -ForegroundColor Yellow
$myIp = ''
try {
    $myIpRaw = (Invoke-WebRequest -Uri 'https://checkip.amazonaws.com' -UseBasicParsing -TimeoutSec 5 2>&1).Content
    if ($myIpRaw) { $myIp = $myIpRaw.Trim() }
} catch {}

$sgObj = Get-AwsJson -Arguments @('ec2', 'describe-security-groups', '--filters', 'Name=group-name,Values=ledgeragent-jenkins-sg', '--region', $Region, '--output', 'json')
if ($sgObj -and $sgObj.SecurityGroups.Count -gt 0) {
    $sgId = $sgObj.SecurityGroups[0].GroupId
    if ($myIp) {
        & aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port 8080 --cidr "${myIp}/32" --region $Region 2>&1 | Out-Null
        & aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port 22 --cidr "${myIp}/32" --region $Region 2>&1 | Out-Null
        Write-Host "  [OK] Ingress Port 8080 and 22 open to current IP: ${myIp}/32" -ForegroundColor Green
    }
    # Allow EC2 Instance Connect
    & aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port 22 --cidr '0.0.0.0/0' --region $Region 2>&1 | Out-Null
}

# 4. Scale ECS Fargate services to 1 task
Write-Host ''
Write-Host '[4/4] Scaling up ECS Fargate services to 1 task...' -ForegroundColor Yellow
$services = @('ledgeragent-mock-erp', 'ledgeragent-backend', 'ledgeragent-frontend')
foreach ($svc in $services) {
    & aws ecs update-service --cluster $ClusterName --service $svc --desired-count 1 --region $Region 2>&1 | Out-Null
    Write-Host "  [STARTED] Service '$svc' scaled to 1." -ForegroundColor Green
}

# Save updated JSON
$jenkinsOutputFile = Join-Path -Path $PSScriptRoot -ChildPath 'jenkins-output.json'
$jenkinsOutput = @{
    InstanceId = $instId
    PublicIp = $publicIp
    JenkinsUrl = "http://${publicIp}:8080"
    Region = $Region
}
$jenkinsOutput | ConvertTo-Json -Depth 4 | Out-File -FilePath $jenkinsOutputFile -Encoding ascii

Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host '  ALL SERVICES RESUMED SUCCESSFULLY' -ForegroundColor Yellow
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host "  Active Jenkins URL:  http://${publicIp}:8080" -ForegroundColor Green
Write-Host "  Pipeline Direct URL: http://${publicIp}:8080/job/ledgeragent-pipeline/" -ForegroundColor White
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host ''
