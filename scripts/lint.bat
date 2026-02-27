@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0.."

cd /d "%ROOT%\backend"
uv run ruff check app/ tests/
if errorlevel 1 echo [WARN] Ruff reported issues.

uv run mypy app/
if errorlevel 1 echo [WARN] Mypy reported issues.

cd /d "%ROOT%\frontend"
pnpm lint
if errorlevel 1 echo [WARN] ESLint reported issues.

pause
