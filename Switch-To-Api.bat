@echo off
setlocal EnableExtensions
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Switch-CodexMode.ps1" -Mode ApiManaged
if errorlevel 1 (
    echo.
    echo [ERROR] Failed to switch to API mode.
    pause
    exit /b 1
)
echo.
echo Done. Use CC Switch to select your API provider.
pause
