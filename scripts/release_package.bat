@echo off
chcp 65001 >nul
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release_package.ps1" %*
if errorlevel 1 (
  echo [ERROR] Release package failed.
  exit /b 1
)

echo [INFO] Release package completed.
