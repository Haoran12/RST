@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0.."
cd /d "%ROOT%"

where python >nul 2>&1
if errorlevel 1 (
  echo [WARN] Python not found. Trying winget install Python 3.12...
  where winget >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] Python not found and winget unavailable. Install Python 3.12+ manually, then rerun.
    exit /b 1
  )
  winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
  where python >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] Python install attempted but python is still unavailable in PATH.
    echo [ERROR] Open a new terminal and rerun scripts\setup.bat.
    exit /b 1
  )
)

where node >nul 2>&1
if errorlevel 1 (
  echo [WARN] Node.js not found. Trying winget install Node.js LTS...
  where winget >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] Node.js not found and winget unavailable. Install Node.js 18+ manually, then rerun.
    exit /b 1
  )
  winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
  where node >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] Node.js install attempted but node is still unavailable in PATH.
    echo [ERROR] Open a new terminal and rerun scripts\setup.bat.
    exit /b 1
  )
)

where uv >nul 2>&1
if errorlevel 1 (
  echo [INFO] uv not found. Installing via pip...
  python -m pip install uv
  if errorlevel 1 (
    echo [ERROR] Failed to install uv.
    exit /b 1
  )
)

where pnpm >nul 2>&1
if errorlevel 1 (
  echo [INFO] pnpm not found. Installing via corepack...
  corepack enable
  corepack prepare pnpm@latest --activate
  if errorlevel 1 (
    echo [ERROR] Failed to install pnpm via corepack.
    exit /b 1
  )
)

echo [INFO] Installing backend dependencies (locked)...
cd /d "%ROOT%\backend"
uv sync --all-extras --frozen
if errorlevel 1 (
  echo [ERROR] Backend dependency install failed.
  exit /b 1
)

echo [INFO] Installing frontend dependencies (locked)...
cd /d "%ROOT%\frontend"
pnpm install --frozen-lockfile
if errorlevel 1 (
  echo [ERROR] Frontend dependency install failed.
  exit /b 1
)

cd /d "%ROOT%"
if not exist ".env" (
  copy ".env.example" ".env" >nul
  echo [INFO] Created .env from .env.example
)

echo [INFO] Setup complete.
pause

