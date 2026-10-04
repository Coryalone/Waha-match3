@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\Build-APK-Standard.ps1"
set "run_status=%errorlevel%"
pause
exit /b %run_status%

