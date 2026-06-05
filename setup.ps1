# NutrAI 개발환경 초기 설정 (최초 1회 실행)
# 실행: PowerShell -ExecutionPolicy Bypass -File setup.ps1

param(
    [switch]$SkipModel
)

$ErrorActionPreference = "Continue"
$ROOT = $PSScriptRoot

function Write-Step($step, $msg) { Write-Host "" ; Write-Host "[Step $step] $msg" -ForegroundColor Cyan }
function Write-OK($msg)          { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Warn($msg)        { Write-Host "  !!  $msg" -ForegroundColor Yellow }
function Write-Fail($msg)        { Write-Host "  XX  $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   NutrAI 개발환경 초기 설정" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ── Step 1: Ollama 설치 확인 ─────────────────────────────────
Write-Step 1 "Ollama 설치 확인"

$ollamaExe = ""
$ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
$candidates = @(
    "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe",
    "$env:ProgramFiles\Ollama\ollama.exe"
)
if ($ollamaCmd) { $candidates += $ollamaCmd.Source }

foreach ($p in $candidates) {
    if ($p -and (Test-Path $p)) { $ollamaExe = $p; break }
}

if ($ollamaExe) {
    Write-OK "Ollama 이미 설치됨: $ollamaExe"
} else {
    Write-Warn "Ollama 미설치. 다운로드 중 (약 200MB)..."
    $installer = "$env:TEMP\OllamaSetup.exe"
    Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $installer -UseBasicParsing
    Write-Host "  설치 중... (설치 창이 닫힐 때까지 기다려주세요)" -ForegroundColor Yellow
    Start-Process -FilePath $installer -Wait
    $ollamaExe = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
    if (-not (Test-Path $ollamaExe)) {
        Write-Fail "설치 실패. https://ollama.com 에서 수동 설치 후 다시 실행하세요."
        exit 1
    }
    $env:PATH = "$env:LOCALAPPDATA\Programs\Ollama;$env:PATH"
    Write-OK "Ollama 설치 완료: $ollamaExe"
}

# ── Step 2: Python 패키지 설치 ──────────────────────────────
Write-Step 2 "Python 패키지 확인 (langchain 계열)"

$pkgsMissing = $false
foreach ($pkg in @("langchain", "langchain_ollama", "langchain_community", "langchain_core")) {
    python -c "import $pkg" | Out-Null
    if ($LASTEXITCODE -ne 0) { $pkgsMissing = $true; break }
}

if (-not $pkgsMissing) {
    Write-OK "langchain 계열 이미 설치됨"
} else {
    Write-Host "  pip install 중... (수 분 소요)" -ForegroundColor Yellow
    python -m pip install "langchain==0.3.25" "langchain-ollama==0.3.3" "langchain-community==0.3.24" -q
    Write-OK "langchain 계열 설치 완료"
}

# ── Step 3: qwen3:8b 모델 풀 ───────────────────────────────
Write-Step 3 "AI 모델 준비 (qwen3:8b, 약 5GB)"

if ($SkipModel) {
    Write-Warn "-SkipModel 로 건너뜀. 나중에 직접 실행: ollama pull qwen3:8b"
} else {
    $ollamaProc = Get-Process -Name "ollama" -ErrorAction SilentlyContinue
    $needStop = $false
    if (-not $ollamaProc) {
        Write-Host "  Ollama 서버 임시 시작 중..." -ForegroundColor Yellow
        Start-Process -FilePath $ollamaExe -ArgumentList "serve" -WindowStyle Hidden
        Start-Sleep -Seconds 4
        $needStop = $true
    }

    Write-Host "  qwen3:8b 다운로드 중... (첫 실행 시 수십 분 소요)" -ForegroundColor Yellow
    & $ollamaExe pull qwen3:8b
    if ($LASTEXITCODE -eq 0) {
        Write-OK "qwen3:8b 준비 완료"
    } else {
        Write-Fail "모델 다운로드 실패. 나중에 직접 실행: ollama pull qwen3:8b"
    }

    if ($needStop) {
        Get-Process -Name "ollama" -ErrorAction SilentlyContinue | Stop-Process -Force
    }
}

# ── 완료 ────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   설정 완료!" -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Green
Write-Host "   이제 dev.ps1 으로 서버를 시작하세요" -ForegroundColor Green
Write-Host "   .\dev.ps1" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
