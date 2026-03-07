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
$packageName = "RST-$Version-update"
$packageDir = Join-Path $releaseRoot $packageName
$zipPath = Join-Path $releaseRoot "$packageName.zip"
$manifestName = "release-manifest.json"

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
  "backend/app",
  "backend/pyproject.toml",
  "backend/uv.lock",
  "backend/__init__.py",
  "frontend/dist",
  "scripts/release_run.bat",
  "scripts/release_start.vbs",
  "scripts/release_stop.vbs",
  "scripts/release_update_from_github.ps1",
  "scripts/release_update_from_github.bat",
  "scripts/setup_release.bat"
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

$updateEntryName = "apply-update.bat"
$readmeName = "UPDATE.md"

$rootUpdate = @"
@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo [INFO] RST update mode
echo [INFO] This package updates app files only.
echo [INFO] Existing .env, data\ and logs\ are preserved.
echo.

if not exist "scripts\setup_release.bat" (
  echo [ERROR] Missing scripts\setup_release.bat
  pause
  exit /b 1
)

if not exist "backend\pyproject.toml" (
  echo [ERROR] Missing backend\pyproject.toml
  pause
  exit /b 1
)

if exist "scripts\release_stop.vbs" (
  echo [INFO] Stopping running RST process...
  wscript.exe "%~dp0scripts\release_stop.vbs"
)

echo.
echo [INFO] Refreshing runtime dependencies...
call "%~dp0scripts\setup_release.bat"
if errorlevel 1 (
  echo.
  echo [ERROR] Update failed during runtime setup.
  echo [ERROR] Existing user data was not removed.
  pause
  exit /b 1
)

echo.
echo [OK] Update complete.
echo [INFO] Existing .env, data\ and logs\ remain untouched.
choice /C YN /N /T 5 /D N /M "Start RST now? [Y/N]: "
if errorlevel 2 exit /b 0
wscript.exe "%~dp0scripts\release_start.vbs"
"@
Write-Utf8File -Path (Join-Path $packageDir $updateEntryName) -Content $rootUpdate

$rootGithubUpdate = @"
@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo [INFO] Checking GitHub for updates...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\release_update_from_github.ps1"
if errorlevel 1 (
  echo.
  echo [ERROR] GitHub update failed.
  pause
  exit /b 1
)
"@
Write-Utf8File -Path (Join-Path $packageDir "update.bat") -Content $rootGithubUpdate

$manifest = @{
  app_name = "RST"
  version = $Version
  repo = "Haoran12/RST"
  update_asset_name = "RST-$Version-update.zip"
  quickstart_asset_name = "RST-$Version-quickstart.zip"
} | ConvertTo-Json
Write-Utf8File -Path (Join-Path $packageDir $manifestName) -Content $manifest

$updateReadme = @'
# RST __VERSION__ Update Package

This update package is designed for existing release users.

What it updates:
- `backend/app`
- `backend/pyproject.toml`
- `backend/uv.lock`
- `frontend/dist`
- release runtime scripts

What it does not include:
- `.env`
- `data/`
- `logs/`
- `backend/.venv/`

Recommended user steps:
1. Stop RST if it is running.
2. Extract this zip directly into the existing RST install folder.
3. Allow Windows to overwrite the packaged app files.
4. Run `apply-update.bat`.
5. Start RST again.

After this update is installed, users can also run `update.bat` to fetch future fixes directly from GitHub Release.

Notes:
- User data stays in place because the update zip does not ship `data/`.
- `.env` is preserved because the update zip does not ship `.env`.
- `apply-update.bat` reruns `scripts\setup_release.bat` so locked backend deps stay in sync.
'@
$updateReadme = $updateReadme.Replace("__VERSION__", $Version)
Write-Utf8File -Path (Join-Path $packageDir $readmeName) -Content $updateReadme

Write-Info "Creating update archive..."
Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "[OK] Update folder: $packageDir" -ForegroundColor Green
Write-Host "[OK] Update zip: $zipPath" -ForegroundColor Green
