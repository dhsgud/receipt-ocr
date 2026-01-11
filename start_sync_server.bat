@echo off
chcp 65001 > nul
echo ========================================
echo   Receipt Ledger Sync Server 시작
echo ========================================
echo.

cd /d "%~dp0sync_server"

echo 서버 IP: 0.0.0.0 (모든 네트워크 인터페이스)
echo 서버 포트: 8888
echo.
echo 외부에서 접속하려면 공유기에서 포트 8888을 열어주세요.
echo.
echo 서버를 종료하려면 Ctrl+C를 누르세요.
echo ========================================
echo.

python -m uvicorn sync_server:app --host 0.0.0.0 --port 8888 --reload

pause
