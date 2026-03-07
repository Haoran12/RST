param(
  [string]$Version = "v0.3",
  [switch]$SkipChecks,
  [switch]$BuildFrontend
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Info([string]$Message) {
  Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Fail([string]$Message) {
  Write-Host "[ERROR] $Message" -ForegroundColor Red
  exit 1
}

function Write-Utf8File([string]$Path, [string]$Content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $normalized = $Content -replace "`r?`n", "`r`n"
  [System.IO.File]::WriteAllText($Path, $normalized, $utf8NoBom)
}

function Join-CodePoints([int[]]$Points) {
  return (-join ($Points | ForEach-Object { [char]$_ }))
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

if (-not $SkipChecks) {
  Write-Info "Running release safety checks..."
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "release_check.ps1")
  if ($LASTEXITCODE -ne 0) {
    Fail "Release safety check failed."
  }
}

$distIndex = Join-Path $repoRoot "frontend/dist/index.html"
if ($BuildFrontend -or -not (Test-Path $distIndex)) {
  if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Fail "pnpm not found. Install frontend toolchain or build dist manually first."
  }

  Write-Info "Building frontend production bundle..."
  Push-Location (Join-Path $repoRoot "frontend")
  try {
    pnpm build
    if ($LASTEXITCODE -ne 0) {
      Fail "Frontend build failed."
    }
  }
  finally {
    Pop-Location
  }
}

if (-not (Test-Path $distIndex)) {
  Fail "frontend/dist/index.html not found. Run scripts/release_build.bat first."
}

$releaseRoot = Join-Path $repoRoot "release"
$packageName = "RST-$Version-quickstart"
$packageDir = Join-Path $releaseRoot $packageName
$zipPath = Join-Path $releaseRoot "$packageName.zip"
$installEntryName = "01-$(Join-CodePoints @(0x5B89,0x88C5,0x90E8,0x7F72)).bat"
$startEntryName = "02-$(Join-CodePoints @(0x542F,0x52A8))RST.vbs"
$stopEntryName = "03-$(Join-CodePoints @(0x5173,0x95ED))RST.vbs"
$quickstartZhName = "README-$(Join-CodePoints @(0x5FEB,0x901F,0x5F00,0x59CB)).md"

if (-not (Test-Path $releaseRoot)) {
  New-Item -ItemType Directory -Path $releaseRoot | Out-Null
}
if (Test-Path $packageDir) {
  Remove-Item -Path $packageDir -Recurse -Force
}
if (Test-Path $zipPath) {
  Remove-Item -Path $zipPath -Force
}
New-Item -ItemType Directory -Path $packageDir | Out-Null

$copyItems = @(
  ".env.example",
  "README.md",
  "README.en.md",
  "README.zh-CN.md",
  "backend/app",
  "backend/pyproject.toml",
  "backend/uv.lock",
  "backend/__init__.py",
  "frontend/dist",
  "scripts/release_run.bat",
  "scripts/release_start.vbs",
  "scripts/release_stop.vbs",
  "scripts/release_check.ps1",
  "scripts/release_check.bat",
  "scripts/release_build.bat",
  "scripts/setup_release.bat",
  "scripts/release_quick_start.bat"
)

foreach ($item in $copyItems) {
  $source = Join-Path $repoRoot $item
  if (-not (Test-Path $source)) {
    Fail "Missing required path: $item"
  }

  $destination = Join-Path $packageDir $item
  $destinationParent = Split-Path -Path $destination -Parent
  if (-not (Test-Path $destinationParent)) {
    New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
  }

  Copy-Item -Path $source -Destination $destination -Recurse -Force
}

Get-ChildItem -Path $packageDir -Recurse -Directory -Filter "__pycache__" |
  Remove-Item -Recurse -Force
Get-ChildItem -Path $packageDir -Recurse -File -Filter "*.pyc" |
  Remove-Item -Force

$rootInstall = @"
@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo [INFO] Starting runtime setup/update...
call "%~dp0scripts\setup_release.bat"
if errorlevel 1 (
  echo.
  echo [ERROR] Setup failed. Please fix the error above and try again.
  pause
  exit /b 1
)

echo.
echo [OK] Runtime setup complete.
echo [INFO] You can now double-click "$startEntryName" to start RST.
choice /C YN /N /T 5 /D N /M "Start RST now? [Y/N]: "
if errorlevel 2 exit /b 0
wscript.exe "%~dp0scripts\release_start.vbs"
"@
Write-Utf8File -Path (Join-Path $packageDir $installEntryName) -Content $rootInstall

$rootStart = @"
Option Explicit

Dim fso, shell, root, scriptPath
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

root = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = root & "\scripts\release_start.vbs"

If Not fso.FileExists(scriptPath) Then
  MsgBox "Missing scripts\release_start.vbs", 48, "RST"
  WScript.Quit 1
End If

shell.Run "wscript.exe """ & scriptPath & """", 0, True
"@
Write-Utf8File -Path (Join-Path $packageDir $startEntryName) -Content $rootStart

$rootStop = @"
Option Explicit

Dim fso, shell, root, scriptPath
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

root = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = root & "\scripts\release_stop.vbs"

If Not fso.FileExists(scriptPath) Then
  MsgBox "Missing scripts\release_stop.vbs", 48, "RST"
  WScript.Quit 1
End If

shell.Run "wscript.exe """ & scriptPath & """", 0, True
"@
Write-Utf8File -Path (Join-Path $packageDir $stopEntryName) -Content $rootStop

$newline = [Environment]::NewLine
$quickstartBody = @(
  ('# RST {0} Quick Start' -f $Version),
  '',
  'After extracting the zip, use the 3 entry files in the package root:',
  '',
  ('- {0}: install or update the runtime dependencies' -f $installEntryName),
  ('- {0}: start RST in the background and open the browser' -f $startEntryName),
  ('- {0}: stop the background RST process' -f $stopEntryName),
  '',
  'Recommended order:',
  '',
  ('1. Run {0}' -f $installEntryName),
  ('2. Then run {0}' -f $startEntryName),
  ('3. When finished, run {0}' -f $stopEntryName),
  '',
  'Notes:',
  '',
  '- .env is created from .env.example when needed',
  '- background logs and PID files are stored under logs/',
  '- advanced helper scripts remain under scripts/'
) -join $newline
Write-Utf8File -Path (Join-Path $packageDir $quickstartZhName) -Content $quickstartBody
Write-Utf8File -Path (Join-Path $packageDir "QUICKSTART.md") -Content $quickstartBody

Write-Info "Creating package archive..."
Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "[OK] Package folder: $packageDir" -ForegroundColor Green
Write-Host "[OK] Package zip: $zipPath" -ForegroundColor Green
