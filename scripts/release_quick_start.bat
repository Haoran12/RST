@echo off
chcp 65001 >nul
setlocal

call "%~dp0setup_release.bat"
if errorlevel 1 (
  exit /b 1
)

echo [INFO] Starting RST in release mode...
wscript.exe "%~dp0release_start.vbs"
