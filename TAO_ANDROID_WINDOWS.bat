@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0TAO_ANDROID_WINDOWS.ps1"
pause
