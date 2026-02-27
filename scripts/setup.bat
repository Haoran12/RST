@echo off
chcp 65001 >nul
setlocal

cd /d "%~dp0.."

python --version >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Python not found. Please install Python 3.12+.
  exit /b 1
)

node --version >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Node.js not found. Please install Node.js 18+.
  exit /b 1
)

uv --version >nul 2>&1
if errorlevel 1 (
  echo [INFO] uv not found. Installing via pip...
  python -m pip install uv
  if errorlevel 1 (
    echo [ERROR] Failed to install uv.
    exit /b 1
  )
)

pnpm --version >nul 2>&1
if errorlevel 1 (
  echo [INFO] pnpm not found. Installing via npm...
  npm install -g pnpm
  if errorlevel 1 (
    echo [ERROR] Failed to install pnpm.
    exit /b 1
  )
)

echo [INFO] Installing backend dependencies...
cd /d "%~dp0..\backend"
uv sync --all-extras
if errorlevel 1 (
  echo [ERROR] Backend dependency install failed.
  exit /b 1
)

echo [INFO] Installing frontend dependencies...
cd /d "%~dp0..\frontend"
pnpm install
if errorlevel 1 (
  echo [ERROR] Frontend dependency install failed.
  exit /b 1
)

cd /d "%~dp0.."
if not exist ".env" (
  copy ".env.example" ".env" >nul
  echo [INFO] Created .env from .env.example
)

echo [INFO] Setup complete.
pause
