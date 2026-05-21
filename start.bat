@echo off
echo [1] 서버 시작 중...
start /B "" ".venv\Scripts\python.exe" -m uvicorn server.main:app --host 0.0.0.0 --port 8000

timeout /t 3 /nobreak >nul

echo [2] adb 터널 연결 중...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000

echo [3] 완료! 앱을 실행하세요.
pause
