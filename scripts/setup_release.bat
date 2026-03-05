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
    echo [ERROR] Open a new terminal and rerun scripts\setup_release.bat.
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

echo [INFO] Installing backend runtime dependencies (locked)...
cd /d "%ROOT%\backend"
uv sync --frozen
if errorlevel 1 (
  echo [ERROR] Backend dependency install failed.
  exit /b 1
)

cd /d "%ROOT%"
if not exist ".env" (
  copy ".env.example" ".env" >nul
  echo [INFO] Created .env from .env.example
)

echo [INFO] Release runtime setup complete.
