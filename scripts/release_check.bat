@echo off
chcp 65001 >nul
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release_check.ps1"
if errorlevel 1 (
  echo [ERROR] Release safety check failed.
  exit /b 1
)

echo [INFO] Release safety check passed.
pause
