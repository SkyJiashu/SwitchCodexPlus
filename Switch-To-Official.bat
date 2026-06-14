@echo off
setlocal EnableExtensions
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Switch-CodexMode.ps1" -Mode Official
if errorlevel 1 (
    echo.
    echo [ERROR] Failed to switch to Official mode.
    pause
    exit /b 1
)
echo.
echo Done. Start Codex and sign in with your ChatGPT account.
pause
