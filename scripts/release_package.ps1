param(
  [string]$Version = "v0.2",
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
  } finally {
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

# Remove Python cache files from package contents.
Get-ChildItem -Path $packageDir -Recurse -Directory -Filter "__pycache__" |
  Remove-Item -Recurse -Force
Get-ChildItem -Path $packageDir -Recurse -File -Filter "*.pyc" |
  Remove-Item -Force

$quickstart = @"
# RST Quickstart Package

This package is for Windows 10/11.

1. Run `scripts\release_quick_start.bat` for first-time setup and launch.
2. Open http://127.0.0.1:18080/ in your browser.
3. Stop service with `scripts\release_stop.vbs`.

Manual commands:
- Setup runtime only: `scripts\setup_release.bat`
- Run app: `scripts\release_run.bat`

Notes:
- Runtime creates `.env` from `.env.example` when needed.
- Runtime data is stored under `data/` and `logs/`.
"@
Set-Content -Path (Join-Path $packageDir "QUICKSTART.md") -Value $quickstart -Encoding utf8

Write-Info "Creating package archive..."
Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "[OK] Package folder: $packageDir" -ForegroundColor Green
Write-Host "[OK] Package zip: $zipPath" -ForegroundColor Green
