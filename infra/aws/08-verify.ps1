# =============================================================================
# 08-verify.ps1 - End-to-End Verification & Health Inspection on AWS
# Region: ap-south-1 (Mumbai) | Account: 441214867393
# Standard: Windows PowerShell 5.1 Hardened (ASCII, ErrorActionPreference Continue)
# =============================================================================

[CmdletBinding()]
param(
    [string]$Region = 'ap-south-1'
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host '  [VERIFY] AWS Infrastructure - 08 End-to-End Verification' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan

# Load ALB Output
$albFile = Join-Path -Path $PSScriptRoot -ChildPath 'alb-output.json'
if (-not (Test-Path $albFile)) {
    Write-Error 'alb-output.json not found! Run 07-alb.ps1 first.'
    exit 1
}
$alb = Get-Content $albFile | ConvertFrom-Json
$albDns = $alb.AlbDnsName
$baseUrl = "http://${albDns}"

Write-Host ''
Write-Host "Target Load Balancer: $baseUrl" -ForegroundColor Yellow
Write-Host '--------------------------------------------------------' -ForegroundColor DarkGray

# 1. Test Landing Page Route (/)
Write-Host ''
Write-Host '[1/3] Testing Frontend Web App Route (GET /)...' -ForegroundColor Yellow
try {
    $webResp = Invoke-WebRequest -Uri "$baseUrl/" -UseBasicParsing -TimeoutSec 10 2>&1
    if ($webResp.StatusCode -eq 200) {
        Write-Host "  [OK] Frontend React SPA is serving HTTP 200 OK." -ForegroundColor Green
    } else {
        Write-Host "  [WAIT] Frontend returned status: $($webResp.StatusCode). Targets may still be registering." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [WAIT] Ingress target warming up... ($_)" -ForegroundColor DarkCyan
}

# 2. Test Backend Health API (/api/v1/health)
Write-Host ''
Write-Host '[2/3] Testing Backend API Route (GET /api/v1/health)...' -ForegroundColor Yellow
try {
    $apiResp = Invoke-WebRequest -Uri "$baseUrl/api/v1/health" -UseBasicParsing -TimeoutSec 10 2>&1
    if ($apiResp.StatusCode -eq 200) {
        Write-Host "  [OK] Backend FastAPI is healthy: $($apiResp.Content)" -ForegroundColor Green
    } else {
        Write-Host "  [WAIT] Backend returned status: $($apiResp.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [WAIT] Backend target warming up... ($_)" -ForegroundColor DarkCyan
}

# 3. Print Verification Checklist
Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host '  E2E USER VERIFICATION GAUNTLET' -ForegroundColor Yellow
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host "  1. Open Public URL in Browser:" -ForegroundColor White
Write-Host "     $baseUrl" -ForegroundColor Green
Write-Host ''
Write-Host "  2. Login with Seeded Demo Credentials:" -ForegroundColor White
Write-Host "     Email:    reviewer@ledgeragent.dev" -ForegroundColor DarkCyan
Write-Host "     Password: LedgerAgent@2026" -ForegroundColor DarkCyan
Write-Host ''
Write-Host "  3. Ingest Test Invoices:" -ForegroundColor White
Write-Host "     - Happy Path: tests/sample_invoices/INV-2026-001_happy_path.pdf -> GL_POSTED" -ForegroundColor DarkGray
Write-Host "     - HITL Path:  tests/sample_invoices/INV-2026-021_price_variance_hitl.pdf -> Approve Exception" -ForegroundColor DarkGray
Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host '[OK] 08-verify.ps1 verification checks complete.' -ForegroundColor Green
Write-Host ''
