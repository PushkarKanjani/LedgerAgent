# =============================================================================
# LedgerAgent — 3-Service Startup Script (Defensive Local-Dev Mode)
# =============================================================================
# Launches all 3 required services in separate PowerShell windows with explicit env vars:
#   1. Mock ERP Service      -> http://localhost:8001
#   2. FastAPI Backend Core  -> http://localhost:8000
#   3. React Vite Dashboard  -> http://localhost:5173
# =============================================================================

$ProjectRoot = "c:\MyDrive\LedgerAgent"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "🚀 Launching LedgerAgent Multi-Service Cluster..." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Start Mock ERP (Port 8001)
Write-Host "1️⃣ Starting Mock ERP Service on port 8001..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$ProjectRoot'; if (Test-Path '.venv\Scripts\Activate.ps1') { .\.venv\Scripts\Activate.ps1 }; Write-Host '--- Mock ERP (:8001) ---' -ForegroundColor Cyan; python mock_erp\app\main.py"

Start-Sleep -Seconds 2

# 2. Start FastAPI Backend (Port 8000 with host 0.0.0.0 and MOCK_ERP_URL env var)
Write-Host "2️⃣ Starting FastAPI Backend on port 8000..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$ProjectRoot'; if (Test-Path '.venv\Scripts\Activate.ps1') { .\.venv\Scripts\Activate.ps1 }; `$env:MOCK_ERP_URL='http://localhost:8001'; Write-Host '--- FastAPI Backend (:8000) ---' -ForegroundColor Green; python -m uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000"

Start-Sleep -Seconds 2

# 3. Start React Frontend (Port 5173 with Vite proxy enabled)
Write-Host "3️⃣ Starting React Vite Frontend on port 5173..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$ProjectRoot\frontend'; Write-Host '--- React Frontend (:5173) ---' -ForegroundColor Magenta; npm run dev"

Write-Host "`n✅ All 3 services spawned successfully!" -ForegroundColor Green
Write-Host "👉 Dashboard: http://localhost:5173" -ForegroundColor White
Write-Host "👉 Backend Swagger: http://localhost:8000/docs" -ForegroundColor White
Write-Host "👉 Mock ERP Swagger: http://localhost:8001/docs" -ForegroundColor White
