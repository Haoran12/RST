@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0.."

cd /d "%ROOT%\backend"
uv run pytest
if errorlevel 1 echo [WARN] Backend tests failed.

cd /d "%ROOT%\frontend"
pnpm test
if errorlevel 1 echo [WARN] Frontend tests failed.

pause
