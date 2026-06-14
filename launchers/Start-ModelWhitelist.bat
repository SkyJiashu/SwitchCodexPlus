@echo off
setlocal EnableExtensions
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-ModelWhitelist.ps1"
echo.
pause
