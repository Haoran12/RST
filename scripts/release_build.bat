@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0.."

where pnpm >nul 2>&1
if errorlevel 1 (
  echo [ERROR] pnpm not found. Run scripts\setup.bat first.
  exit /b 1
)

echo [INFO] Building frontend production bundle...
cd /d "%ROOT%\frontend"
pnpm build
if errorlevel 1 (
  echo [ERROR] Frontend build failed.
  exit /b 1
)

if not exist "%ROOT%\frontend\dist\index.html" (
  echo [ERROR] frontend\dist\index.html not found after build.
  exit /b 1
)

echo [INFO] Frontend build complete: %ROOT%\frontend\dist
pause
