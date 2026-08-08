# =============================================================================
# 05-push-images.ps1 - Build, Tag, and Push Docker Images to Amazon ECR
# Region: ap-south-1 (Mumbai) | Account: 441214867393
# Standard: Windows PowerShell 5.1 Hardened (ASCII, ErrorActionPreference Continue)
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
Write-Host '  [ECR PUSH] AWS Infrastructure - 05 Docker Image Push' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan

$ecrRegistry = "${Account}.dkr.ecr.${Region}.amazonaws.com"
$projectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName

# 1. Authenticate Docker with Amazon ECR
Write-Host ''
Write-Host '[1/4] Authenticating Docker with Amazon ECR...' -ForegroundColor Yellow
$loginPassword = & aws ecr get-login-password --region $Region 2>&1

if ($LASTEXITCODE -eq 0 -and $loginPassword) {
    $loginPassword | & docker login --username AWS --password-stdin $ecrRegistry 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Docker authenticated with ECR registry: $ecrRegistry" -ForegroundColor Green
    } else {
        Write-Error "Failed to authenticate Docker with $ecrRegistry"
        exit 1
    }
} else {
    Write-Error 'Failed to retrieve ECR login password via AWS CLI.'
    exit 1
}

# Image Definitions: Repo Name -> Dockerfile & Context
$images = @(
    @{
        Name = 'ledgeragent-backend'
        Dockerfile = 'backend/Dockerfile'
        Context = '.'
        Tag = "${ecrRegistry}/ledgeragent-backend:latest"
    },
    @{
        Name = 'ledgeragent-mock-erp'
        Dockerfile = 'mock_erp/Dockerfile'
        Context = '.'
        Tag = "${ecrRegistry}/ledgeragent-mock-erp:latest"
    },
    @{
        Name = 'ledgeragent-frontend'
        Dockerfile = 'frontend/Dockerfile'
        Context = 'frontend'
        Tag = "${ecrRegistry}/ledgeragent-frontend:latest"
    }
)

# 2. Build, Tag, and Push Each Container Image
Write-Host ''
Write-Host '[2/4] Building and pushing container images to ECR...' -ForegroundColor Yellow

Push-Location $projectRoot

try {
    foreach ($img in $images) {
        $name = $img.Name
        $tag = $img.Tag
        $dockerfile = $img.Dockerfile
        $context = $img.Context

        Write-Host ''
        Write-Host "  [BUILD] Building $name ($tag)..." -ForegroundColor Cyan
        & docker build -t $name -t $tag -f $dockerfile $context
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Docker build failed for $name"
            exit 1
        }

        Write-Host "  [PUSH] Pushing $tag to Amazon ECR..." -ForegroundColor Green
        & docker push $tag
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Docker push failed for $tag"
            exit 1
        }
        Write-Host "  [OK] Pushed $name to ECR successfully." -ForegroundColor Green
    }
} finally {
    Pop-Location
}

# 3. Verify Pushed Image Digests in ECR
Write-Host ''
Write-Host '[3/4] Verifying image digests in ECR repositories...' -ForegroundColor Yellow

foreach ($img in $images) {
    $name = $img.Name
    $describe = Get-AwsJson -Arguments @('ecr', 'describe-images', '--repository-name', $name, '--region', $Region, '--output', 'json')
    if ($describe -and $describe.imageDetails.Count -gt 0) {
        $digest = $describe.imageDetails[0].imageDigest
        $sizeMb = [math]::Round($describe.imageDetails[0].imageSizeInBytes / (1024 * 1024), 2)
        Write-Host "  [OK] $name -> Digest: $digest ($sizeMb MB)" -ForegroundColor Green
    }
}

# 4. Monthly Cost Estimation
Write-Host ''
Write-Host '[4/4] Monthly Cost Estimation for ECR Storage:' -ForegroundColor Yellow
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host '  ECR 500 MB Free Tier Allowance:       $0.00 / month' -ForegroundColor Green
Write-Host '  Estimated Monthly ECR Cost:           ~$0.10 / month' -ForegroundColor Green
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host ''
Write-Host '[OK] 05-push-images.ps1 execution completed successfully.' -ForegroundColor Green
Write-Host ''
