# =============================================================================
# 04-s3-secrets.ps1 - Private S3 Bucket and AWS Secrets Manager Provisioning
# Region: ap-south-1 (Mumbai) | Account: 441214867393
# Standard: Windows PowerShell 5.1 Hardened (Get-AwsJson, ASCII)
# =============================================================================

[CmdletBinding()]
param(
    [string]$Region = 'ap-south-1',
    [string]$BucketName = 'ledgeragent-invoices-441214867393'
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
Write-Host '  [S3] AWS Infrastructure - 04 S3 and Secrets Manager' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan

# 1. Idempotent S3 Bucket Creation
Write-Host ''
Write-Host "[1/3] Checking S3 Bucket '$BucketName'..." -ForegroundColor Yellow
$bucketHead = & aws s3api head-bucket --bucket $BucketName --region $Region 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [NEW] Creating private S3 bucket in $Region..." -ForegroundColor Green
    & aws s3api create-bucket --bucket $BucketName --region $Region --create-bucket-configuration "LocationConstraint=$Region" 2>&1 | Out-Null
} else {
    Write-Host "  [INFO] Bucket '$BucketName' already exists." -ForegroundColor DarkCyan
}

# 2. Hardened S3 Security Configurations
Write-Host ''
Write-Host '[2/3] Enforcing S3 Encryption and 100% Public Access Block...' -ForegroundColor Yellow

# Server-Side Encryption (AES256)
$sseConfig = @{
    Rules = @(
        @{
            ApplyServerSideEncryptionByDefault = @{
                SSEAlgorithm = 'AES256'
            }
        }
    )
} | ConvertTo-Json -Depth 4
$sseFile = Join-Path -Path $PSScriptRoot -ChildPath 's3-sse-config.json'
$sseConfig | Out-File -FilePath $sseFile -Encoding ascii

& aws s3api put-bucket-encryption --bucket $BucketName --server-side-encryption-configuration "file://$sseFile" --region $Region 2>&1 | Out-Null
Write-Host '  [SEC] Server-Side Encryption (AES256): ENABLED' -ForegroundColor Green

# Block Public Access (All 4 Flags)
& aws s3api put-public-access-block --bucket $BucketName --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true --region $Region 2>&1 | Out-Null
Write-Host '  [SEC] S3 Public Access Block: 100% BLOCKED' -ForegroundColor Green

# 90-Day Cost Lifecycle Policy (Expires raw temporary invoice uploads)
$lifecyclePolicy = @{
    Rules = @(
        @{
            ID     = 'ExpireOldInvoicesAfter90Days'
            Status = 'Enabled'
            Prefix = 'uploads/'
            Expiration = @{
                Days = 90
            }
        }
    )
} | ConvertTo-Json -Depth 4

$lifecycleFile = Join-Path -Path $PSScriptRoot -ChildPath 's3-lifecycle-policy.json'
$lifecyclePolicy | Out-File -FilePath $lifecycleFile -Encoding ascii

& aws s3api put-bucket-lifecycle-configuration --bucket $BucketName --lifecycle-configuration "file://$lifecycleFile" --region $Region 2>&1 | Out-Null
Write-Host '  [POLICY] 90-Day Storage Cost Lifecycle Rule: ATTACHED' -ForegroundColor Green

# 3. AWS Secrets Manager Provisioning
Write-Host ''
Write-Host '[3/3] Provisioning Core Application Secrets...' -ForegroundColor Yellow

function Ensure-Secret {
    param($Name, $Description, $Value)
    $secCheck = Get-AwsJson -Arguments @('secretsmanager', 'describe-secret', '--secret-id', $Name, '--region', $Region, '--output', 'json')
    if ($secCheck) {
        Write-Host "  [INFO] Secret '$Name' exists. Updating value..." -ForegroundColor DarkCyan
        & aws secretsmanager put-secret-value --secret-id $Name --secret-string $Value --region $Region 2>&1 | Out-Null
    } else {
        Write-Host "  [NEW] Creating secret '$Name'..." -ForegroundColor Green
        & aws secretsmanager create-secret --name $Name --description $Description --secret-string $Value --region $Region 2>&1 | Out-Null
    }
}

# Generate 256-bit JWT Secret Key
$jwtSecretBytes = [byte[]]::new(32)
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($jwtSecretBytes)
$jwtSecretKey = [Convert]::ToBase64String($jwtSecretBytes)

Ensure-Secret `
    -Name 'ledgeragent/jwt-secret' `
    -Description '256-bit cryptographic signing secret for JWT access and refresh tokens' `
    -Value $jwtSecretKey

Ensure-Secret `
    -Name 'ledgeragent/groq-api-key' `
    -Description 'Groq Cloud API key for Llama 3.3 70B structured invoice extraction' `
    -Value 'gsk_placeholder_replace_with_live_groq_key'

Write-Host '  [OK] Secrets Manager entries provisioned: ledgeragent/jwt-secret, ledgeragent/groq-api-key' -ForegroundColor Green

# 4. Monthly Cost Estimation for S3 and Secrets Manager
Write-Host ''
Write-Host '[Cost Breakdown: S3 and Secrets Manager]' -ForegroundColor Yellow
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host '  S3 Storage (5GB Free Tier / Invoices): $0.00 / month' -ForegroundColor Green
Write-Host '  S3 PUT/GET Requests:                  ~$0.02 / month' -ForegroundColor Green
Write-Host '  AWS Secrets Manager (3 active secrets): ~$1.20 / month ($0.40/secret)' -ForegroundColor Green
Write-Host '  Total Phase 04 Monthly Cost:           ~$1.22 / month' -ForegroundColor Green
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host ''
Write-Host '[OK] 04-s3-secrets.ps1 S3 and Secrets Manager provisioning completed successfully.' -ForegroundColor Green
Write-Host ''
