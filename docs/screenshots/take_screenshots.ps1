# NutrAI 주요 화면 스크린샷 자동 캡처 스크립트
# 실행 방법: PowerShell 터미널에서 .\take_screenshots.ps1

$adb    = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$device = "emulator-5554"
$outDir = "c:\Users\user\NutrAI\docs\screenshots"

function Capture($remote, $local) {
    & $adb -s $device shell screencap -p $remote
    Start-Sleep -Milliseconds 800
    & $adb -s $device pull $remote "$outDir\$local"
    Write-Host "저장 완료: $local"
}

# ── 1. 기록 탭 (현재 화면) ────────────────────────────────────────
Write-Host "`n[1/5] 기록 탭 캡처 중..."
Capture /sdcard/cap.png "screen_record.png"

# ── 2. + 버튼 탭 → 식단 추가 화면 ───────────────────────────────
Write-Host "`n[2/5] + 버튼 탭 → 식단 추가 화면..."
& $adb -s $device shell input tap 540 2350
Start-Sleep -Seconds 2
Capture /sdcard/cap.png "screen_food_add.png"

# ── 3. 뒤로 가기 → 리포트 탭 ────────────────────────────────────
Write-Host "`n[3/5] 뒤로 가기 후 리포트 탭..."
& $adb -s $device shell input keyevent 4
Start-Sleep -Milliseconds 800
& $adb -s $device shell input tap 494 2350
Start-Sleep -Seconds 2
Capture /sdcard/cap.png "screen_report.png"

# ── 4. 추천 탭 ──────────────────────────────────────────────────
Write-Host "`n[4/5] 추천 탭..."
& $adb -s $device shell input tap 635 2350
Start-Sleep -Seconds 2
Capture /sdcard/cap.png "screen_recommend.png"

# ── 5. 홈 탭 ────────────────────────────────────────────────────
Write-Host "`n[5/5] 홈 탭..."
& $adb -s $device shell input tap 71 2350
Start-Sleep -Seconds 2
Capture /sdcard/cap.png "screen_home_final.png"

Write-Host "`n모든 스크린샷 저장 완료 → $outDir"
Get-ChildItem $outDir -Filter "*.png" | Select-Object Name, LastWriteTime, Length
