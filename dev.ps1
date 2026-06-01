# NutrAI 통합 개발 서버 실행기
# 실행: .\dev.ps1
# 옵션: .\dev.ps1 -NoAdb      (adb 포워딩 생략)
#       .\dev.ps1 -NoReload   (uvicorn --reload 끔)

param(
    [switch]$NoAdb,
    [switch]$NoReload
)

$ROOT   = $PSScriptRoot
$ADB    = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$PYTHON = "python"

# Ollama 실행 파일 탐색 (PS 5.1 호환)
$ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
$ollamaCandidates = @(
    "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe",
    "$env:ProgramFiles\Ollama\ollama.exe"
)
if ($ollamaCmd) { $ollamaCandidates += $ollamaCmd.Source }
$OLLAMA = $ollamaCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

function Write-Banner($msg) { Write-Host ""; Write-Host "  >> $msg" -ForegroundColor Cyan }
function Write-OK($msg)     { Write-Host "     [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg)   { Write-Host "     [!!] $msg" -ForegroundColor Yellow }
function Write-Fail($msg)   { Write-Host "     [XX] $msg" -ForegroundColor Red }

function Test-Port($port) {
    try {
        $tcp  = New-Object System.Net.Sockets.TcpClient
        $conn = $tcp.BeginConnect("127.0.0.1", $port, $null, $null)
        $ok   = $conn.AsyncWaitHandle.WaitOne(500)
        $tcp.Close()
        return $ok
    } catch { return $false }
}

function Wait-Http($url, $timeoutSec = 60) {
    $end = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $end) {
        try {
            $null = Invoke-WebRequest -Uri $url -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            return $true
        } catch { Start-Sleep -Milliseconds 1000 }
    }
    return $false
}

# ════════════════════════════════════════════════════
Write-Host ""
Write-Host "  +======================================+" -ForegroundColor Cyan
Write-Host "  |   NutrAI 통합 개발환경 시작         |" -ForegroundColor Cyan
Write-Host "  +======================================+" -ForegroundColor Cyan

# ── 1. 사전 점검 ─────────────────────────────────────────────
Write-Banner "사전 점검"

if (-not $OLLAMA) {
    Write-Fail "Ollama 미설치. setup.ps1 을 먼저 실행하세요."
    exit 1
}
Write-OK "Ollama: $OLLAMA"

$langchainCheck = python -c "import langchain_ollama" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Fail "langchain_ollama 미설치. setup.ps1 을 먼저 실행하세요."
    exit 1
}
Write-OK "langchain_ollama: 설치됨"

# ── 2. Ollama 서버 ───────────────────────────────────────────
Write-Banner "Ollama 서버"

if (Test-Port 11434) {
    Write-OK "이미 실행 중 (포트 11434)"
} else {
    Write-Host "     시작 중..." -ForegroundColor Yellow
    Start-Process -FilePath $OLLAMA -ArgumentList "serve" -WindowStyle Minimized
    $ready = Wait-Http "http://localhost:11434" 20
    if ($ready) { Write-OK "시작됨" }
    else         { Write-Warn "응답 없음 — 계속 진행합니다" }
}

# ── 3. FastAPI 서버 ──────────────────────────────────────────
Write-Banner "FastAPI 서버 (포트 8000)"

if (Test-Port 8000) {
    Write-Warn "포트 8000 이미 사용 중. 기존 서버를 유지합니다."
} else {
    $reloadArg = ""
    if (-not $NoReload) { $reloadArg = "--reload" }
    $serverCmd = "$PYTHON -m uvicorn server.main:app --host 0.0.0.0 --port 8000 $reloadArg"

    Start-Process -FilePath "cmd.exe" `
        -ArgumentList "/k title NutrAI-Server && $serverCmd" `
        -WorkingDirectory $ROOT

    Write-Host "     서버 준비 대기 중 (최대 90초)..." -ForegroundColor Yellow
    $ready = Wait-Http "http://localhost:8000/health" 90
    if ($ready) { Write-OK "FastAPI 준비 완료" }
    else         { Write-Warn "응답 없음 — 서버 터미널 창에서 오류를 확인하세요" }
}

# ── 4. adb 포트 포워딩 ──────────────────────────────────────
Write-Banner "adb 포트 포워딩"

if ($NoAdb) {
    Write-Warn "-NoAdb 플래그 — 건너뜀"
} elseif (-not (Test-Path $ADB)) {
    Write-Warn "adb 없음: $ADB"
} else {
    $devices = & $ADB devices 2>&1 | Select-String "device$"
    if ($devices) {
        & $ADB reverse tcp:8000  tcp:8000  2>&1 | Out-Null
        & $ADB reverse tcp:11434 tcp:11434 2>&1 | Out-Null
        Write-OK "tcp:8000, tcp:11434 포워딩 완료"
    } else {
        Write-Warn "연결된 Android 기기/에뮬레이터 없음 — 건너뜀"
    }
}

# ── 5. 상태 요약 ─────────────────────────────────────────────
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |  서비스              URL                  |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |  Ollama    http://localhost:11434         |" -ForegroundColor Green
Write-Host "  |  FastAPI   http://localhost:8000          |" -ForegroundColor Green
Write-Host "  |  API 문서  http://localhost:8000/docs     |" -ForegroundColor Green
Write-Host "  |  헬스체크  http://localhost:8000/health   |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  앱 실행:  cd app  &&  flutter run" -ForegroundColor Yellow
Write-Host "  서버 종료: 서버 터미널 창을 닫으세요" -ForegroundColor Gray
Write-Host ""
