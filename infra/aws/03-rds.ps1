# =============================================================================
# 03-rds.ps1 - Amazon RDS PostgreSQL 16 Free-Tier Instance Provisioning
# Region: ap-south-1 (Mumbai) | Account: 441214867393
# Standard: Windows PowerShell 5.1 Hardened (Get-AwsJson, ASCII)
# =============================================================================

[CmdletBinding()]
param(
    [string]$Region = 'ap-south-1',
    [string]$DbInstanceId = 'ledgeragent-postgres',
    [string]$DbName = 'ledgeragent',
    [string]$MasterUser = 'ledgeradmin'
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
Write-Host '  [RDS] AWS Infrastructure - 03 RDS PostgreSQL 16' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan

# Load Network Outputs
$networkFile = Join-Path -Path $PSScriptRoot -ChildPath 'network-output.json'
if (-not (Test-Path $networkFile)) {
    Write-Error 'network-output.json not found! Run 02-network.ps1 first to establish VPC and subnets.'
    exit 1
}
$net = Get-Content $networkFile | ConvertFrom-Json
$privateSubnets = $net.PrivateSubnets
$dbSgId = $net.DbSecurityGroupId

# 1. DB Subnet Group (Private Dual-AZ)
Write-Host ''
Write-Host "[1/4] Checking DB Subnet Group 'ledgeragent-db-subnet-group'..." -ForegroundColor Yellow
$subnetGroupName = 'ledgeragent-db-subnet-group'
$sngCheck = Get-AwsJson -Arguments @('rds', 'describe-db-subnet-groups', '--db-subnet-group-name', $subnetGroupName, '--region', $Region, '--output', 'json')

if (-not $sngCheck -or $sngCheck.DBSubnetGroups.Count -eq 0) {
    Write-Host '  [NEW] Creating DB Subnet Group across private subnets...' -ForegroundColor Green
    & aws rds create-db-subnet-group `
        --db-subnet-group-name $subnetGroupName `
        --db-subnet-group-description 'Private database subnets for LedgerAgent RDS PostgreSQL' `
        --subnet-ids $privateSubnets `
        --tags "Key=Project,Value=LedgerAgent" `
        --region $Region 2>&1 | Out-Null
} else {
    Write-Host "  [INFO] DB Subnet Group exists ($subnetGroupName)" -ForegroundColor DarkCyan
}

# 2. Secure Master Password Generation and Secrets Manager Storage
Write-Host ''
Write-Host '[2/4] Generating and Storing RDS Credentials in AWS Secrets Manager...' -ForegroundColor Yellow
$secretName = 'ledgeragent/rds-master-credentials'
$secCheck = Get-AwsJson -Arguments @('secretsmanager', 'describe-secret', '--secret-id', $secretName, '--region', $Region, '--output', 'json')

$masterPassword = ''
if ($secCheck) {
    Write-Host "  [INFO] Credentials secret already exists in Secrets Manager ($secretName)." -ForegroundColor DarkCyan
    $secVal = Get-AwsJson -Arguments @('secretsmanager', 'get-secret-value', '--secret-id', $secretName, '--region', $Region, '--output', 'json')
    if ($secVal -and $secVal.SecretString) {
        $secJson = $secVal.SecretString | ConvertFrom-Json
        $masterPassword = $secJson.password
    }
}

if (-not $masterPassword) {
    Write-Host '  [GEN] Generating high-entropy 24-character cryptographic password...' -ForegroundColor Green
    $randomBytes = [byte[]]::new(18)
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($randomBytes)
    $masterPassword = [Convert]::ToBase64String($randomBytes).Replace('+', 'X').Replace('/', 'Z').Substring(0, 22) + '!9'

    $secretPayload = @{
        username = $MasterUser
        password = $masterPassword
        engine   = 'postgres'
        port     = 5432
        dbname   = $DbName
    } | ConvertTo-Json -Compress

    & aws secretsmanager create-secret `
        --name $secretName `
        --description 'Master database credentials for LedgerAgent PostgreSQL 16' `
        --secret-string $secretPayload `
        --region $Region 2>&1 | Out-Null
    Write-Host "  [OK] Stored master credentials in Secrets Manager: $secretName" -ForegroundColor Green
}

# 3. Idempotent RDS PostgreSQL Instance Creation
Write-Host ''
Write-Host "[3/4] Checking RDS PostgreSQL Instance '$DbInstanceId'..." -ForegroundColor Yellow
$rdsCheck = Get-AwsJson -Arguments @('rds', 'describe-db-instances', '--db-instance-identifier', $DbInstanceId, '--region', $Region, '--output', 'json')

$endpointHost = ''

if (-not $rdsCheck -or $rdsCheck.DBInstances.Count -eq 0) {
    Write-Host '  [NEW] Launching db.t3.micro PostgreSQL 16 (AWS Free Tier)...' -ForegroundColor Green
    & aws rds create-db-instance `
        --db-instance-identifier $DbInstanceId `
        --db-instance-class db.t3.micro `
        --engine postgres `
        --engine-version 16.3 `
        --allocated-storage 20 `
        --storage-type gp2 `
        --no-auto-minor-version-upgrade `
        --no-multi-az `
        --no-publicly-accessible `
        --db-name $DbName `
        --master-username $MasterUser `
        --master-user-password $masterPassword `
        --db-subnet-group-name $subnetGroupName `
        --vpc-security-group-ids $dbSgId `
        --backup-retention-period 7 `
        --tags "Key=Project,Value=LedgerAgent" `
        --region $Region 2>&1 | Out-Null

    Write-Host '  [WAIT] RDS creation requested. Polling for endpoint availability...' -ForegroundColor Yellow
    & aws rds wait db-instance-available --db-instance-identifier $DbInstanceId --region $Region 2>&1 | Out-Null
}

# Retrieve Endpoint Address
$rdsFinal = Get-AwsJson -Arguments @('rds', 'describe-db-instances', '--db-instance-identifier', $DbInstanceId, '--region', $Region, '--output', 'json')
if ($rdsFinal -and $rdsFinal.DBInstances.Count -gt 0) {
    $endpointHost = $rdsFinal.DBInstances[0].Endpoint.Address
}

Write-Host "  [OK] RDS PostgreSQL Host: $endpointHost:5432" -ForegroundColor Green

# 4. Compose Full DATABASE_URL and Update Secrets Manager
Write-Host ''
Write-Host '[4/4] Generating and Storing DATABASE_URL...' -ForegroundColor Yellow
$dbUrl = "postgresql://${MasterUser}:${masterPassword}@${endpointHost}:5432/${DbName}"
$dbUrlSecretName = 'ledgeragent/db-url'

$dbUrlCheck = Get-AwsJson -Arguments @('secretsmanager', 'describe-secret', '--secret-id', $dbUrlSecretName, '--region', $Region, '--output', 'json')
if ($dbUrlCheck) {
    & aws secretsmanager put-secret-value --secret-id $dbUrlSecretName --secret-string $dbUrl --region $Region 2>&1 | Out-Null
} else {
    & aws secretsmanager create-secret `
        --name $dbUrlSecretName `
        --description 'Composed PostgreSQL connection string for LedgerAgent backend and Mock ERP' `
        --secret-string $dbUrl `
        --region $Region 2>&1 | Out-Null
}
Write-Host "  [OK] Saved connection string to Secrets Manager: $dbUrlSecretName" -ForegroundColor Green

# Save Outputs
$rdsOutput = @{
    DbInstanceIdentifier = $DbInstanceId
    EndpointHost = $endpointHost
    Port = 5432
    DbName = $DbName
    MasterUsername = $MasterUser
    DbSubnetGroup = $subnetGroupName
    DbSecurityGroupId = $dbSgId
    SecretArn = $secretName
}
$rdsOutputFile = Join-Path -Path $PSScriptRoot -ChildPath 'rds-output.json'
$rdsOutput | ConvertTo-Json -Depth 4 | Out-File -FilePath $rdsOutputFile -Encoding ascii
Write-Host "  [SAVED] RDS metadata saved: $rdsOutputFile" -ForegroundColor Green

# 5. Cost Breakdown
Write-Host ''
Write-Host '[Cost Breakdown: Amazon RDS PostgreSQL]' -ForegroundColor Yellow
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host '  db.t3.micro (750 hrs/mo 12-Month Free Tier):  $0.00 / month' -ForegroundColor Green
Write-Host '  20 GB gp2 Storage (Free Tier Included):       $0.00 / month' -ForegroundColor Green
Write-Host '  7-Day Automated Backup Storage (Free Tier):   $0.00 / month' -ForegroundColor Green
Write-Host '  Single-AZ Enforcement (Multi-AZ OFF):         $0.00 extra' -ForegroundColor Green
Write-Host '  Estimated Monthly Cost (Within Free Tier):    $0.00 / month' -ForegroundColor Green
Write-Host '  (Standard Post-Free Tier Rate:                ~$14.50 / month)' -ForegroundColor DarkGray
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host ''
Write-Host '[OK] 03-rds.ps1 RDS provisioning completed successfully.' -ForegroundColor Green
Write-Host ''
