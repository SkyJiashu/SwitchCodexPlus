@echo off
setlocal EnableExtensions
echo.
echo  SwitchCodexPlus - Setup
echo  =======================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
if errorlevel 1 (
    echo.
    echo [ERROR] Setup failed. See messages above.
    pause
    exit /b 1
)
pause
