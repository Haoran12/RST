@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0.."

start "RST Backend" cmd /k "cd /d %ROOT%\backend && set RST_BACKEND_RELOAD=1&& set RST_SERVE_FRONTEND=0&& uv run python -m app.main"

timeout /t 2 >nul

start "RST Frontend" cmd /k "cd /d %ROOT%\frontend && pnpm dev"

echo Backend: http://127.0.0.1:18080/health
echo Frontend: http://localhost:15173
