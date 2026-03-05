@echo off
chcp 65001 >nul
setlocal

call "%~dp0setup_release.bat"
if errorlevel 1 (
  exit /b 1
)

echo [INFO] Starting RST in release mode...
call "%~dp0release_run.bat"
