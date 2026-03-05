@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0.."

if not exist "%ROOT%\frontend\dist\index.html" (
  echo [ERROR] frontend build not found. Run scripts\release_build.bat first.
  exit /b 1
)

if not exist "%ROOT%\.env" (
  copy "%ROOT%\.env.example" "%ROOT%\.env" >nul
  echo [INFO] Created .env from .env.example
)

cd /d "%ROOT%\backend"
set "RST_BACKEND_RELOAD=0"
set "RST_SERVE_FRONTEND=1"

uv run python -m app.main
