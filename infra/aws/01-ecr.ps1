# =============================================================================
# 01-ecr.ps1 - Idempotent ECR Repository Provisioning and Lifecycle Management
# Region: ap-south-1 (Mumbai) | Account: 441214867393
# Standard: Windows PowerShell 5.1 Hardened (Get-AwsJson helper, ASCII)
# =============================================================================

[CmdletBinding()]
param(
    [string]$Region = 'ap-south-1',
    [string]$Account = '441214867393'
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
Write-Host '  [ECR] AWS Infrastructure - 01 ECR Provisioning' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan

$repositories = @(
    'ledgeragent-backend',
    'ledgeragent-mock-erp',
    'ledgeragent-frontend'
)

# Lifecycle Policy JSON (Keep last 5 images to prevent cost sprawl)
$lifecyclePolicy = @{
    rules = @(
        @{
            rulePriority = 1
            description = 'Retain only the 5 most recent container images to control storage costs'
            selection = @{
                tagStatus = 'any'
                countType = 'imageCountMoreThan'
                countNumber = 5
            }
            action = @{
                type = 'expire'
            }
        }
    )
} | ConvertTo-Json -Depth 5

$lifecycleFile = Join-Path -Path $PSScriptRoot -ChildPath 'ecr-lifecycle-policy.json'
$lifecyclePolicy | Out-File -FilePath $lifecycleFile -Encoding ascii

$ecrRegistry = "${Account}.dkr.ecr.${Region}.amazonaws.com"
$createdCount = 0

foreach ($repo in $repositories) {
    Write-Host ''
    Write-Host "[ECR] Checking repository: $repo..." -ForegroundColor Yellow
    
    # 1. Idempotent Repository Check via Get-AwsJson
    $describeJson = Get-AwsJson -Arguments @('ecr', 'describe-repositories', '--repository-names', $repo, '--region', $Region, '--output', 'json')
    
    if ($describeJson -and $describeJson.repositories.Count -gt 0) {
        Write-Host "  [INFO] Repository '$repo' already exists. Skipping creation." -ForegroundColor DarkCyan
    } else {
        Write-Host "  [NEW] Creating repository '$repo' with scan-on-push enabled..." -ForegroundColor Green
        & aws ecr create-repository `
            --repository-name $repo `
            --image-tag-mutability MUTABLE `
            --image-scanning-configuration scanOnPush=true `
            --encryption-configuration encryptionType=AES256 `
            --region $Region 2>&1 | Out-Null
        $createdCount++
    }

    # 2. Attach Storage-Optimized Lifecycle Policy
    Write-Host '  [POLICY] Attaching 5-image retention lifecycle policy...' -ForegroundColor DarkGray
    & aws ecr put-lifecycle-policy `
        --repository-name $repo `
        --lifecycle-policy-text "file://$lifecycleFile" `
        --region $Region 2>&1 | Out-Null
    
    Write-Host "  [OK] Repository Ready: ${ecrRegistry}/${repo}:latest" -ForegroundColor Green
}

# 3. Print Docker Login Command
Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host '  Docker Authentication Command for ECR:' -ForegroundColor Yellow
Write-Host "  aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $ecrRegistry" -ForegroundColor White
Write-Host '========================================================' -ForegroundColor Cyan

# 4. Cost Breakdown Estimation
Write-Host ''
Write-Host '[Cost Breakdown: Amazon ECR]' -ForegroundColor Yellow
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host '  ECR Storage (500 MB Free Tier):       $0.00 / month' -ForegroundColor Green
Write-Host '  Additional Storage (approx 1 GB):     ~$0.10 / month' -ForegroundColor Green
Write-Host '  Image Vulnerability Scans:            $0.00 / month (Basic)' -ForegroundColor Green
Write-Host '  Estimated Monthly ECR Cost:           ~$0.10 / month' -ForegroundColor Green
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host ''
Write-Host '[OK] 01-ecr.ps1 ECR provisioning completed successfully.' -ForegroundColor Green
Write-Host ''
