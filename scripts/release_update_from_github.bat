@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0.."

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release_update_from_github.ps1" %*
exit /b %errorlevel%
