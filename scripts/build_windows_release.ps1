param(
    [switch]$SkipRustBuild,
    [string]$ReleaseNotes = "Windows x64 release build."
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$rustDir = Join-Path $projectRoot "rust"
$releaseDir = Join-Path $projectRoot "release\windows-x64"
$flutterOutputDir = Join-Path $projectRoot "build\windows\x64\runner\Release"
$rustDllPath = Join-Path $rustDir "target\release\rst_core.dll"

Write-Host "Building RST for Windows x64..." -ForegroundColor Cyan
Write-Host "Project root: $projectRoot" -ForegroundColor Gray

# Step 1: Build Rust library (Windows target only)
if (-not $SkipRustBuild) {
    Write-Host "Building Rust library for Windows..." -ForegroundColor Yellow
    Push-Location $rustDir
    try {
        cargo build --release
        if (-not (Test-Path $rustDllPath)) {
            throw "rst_core.dll not found after Rust build"
        }
        Write-Host "Rust library built successfully." -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

# Step 2: Build Flutter Windows app
Write-Host "Building Flutter Windows application..." -ForegroundColor Yellow
Push-Location $projectRoot
try {
    flutter build windows --release
    if (-not (Test-Path $flutterOutputDir)) {
        throw "Flutter Windows output not found: $flutterOutputDir"
    }
    Write-Host "Flutter application built successfully." -ForegroundColor Green
}
finally {
    Pop-Location
}

# Step 3: Copy Rust DLL to output
Write-Host "Copying Rust DLL..." -ForegroundColor Yellow
Copy-Item -Path $rustDllPath -Destination $flutterOutputDir -Force

# Step 4: Create release package
Write-Host "Creating release package..." -ForegroundColor Yellow
if (Test-Path $releaseDir) {
    Remove-Item -Path $releaseDir -Recurse -Force
}
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

# Copy all files from Flutter output
Get-ChildItem -Path $flutterOutputDir | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $releaseDir -Recurse -Force
}

# Summary
$exePath = Join-Path $releaseDir "rst.exe"
$exeFile = Get-Item $exePath
$totalSize = (Get-ChildItem -Path $releaseDir -Recurse | Measure-Object -Property Length -Sum).Sum

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Windows x64 build completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Output: $releaseDir" -ForegroundColor Cyan
Write-Host "Executable: rst.exe ($([Math]::Round($exeFile.Length / 1KB, 1)) KB)"
Write-Host "Total size: $([Math]::Round($totalSize / 1MB, 1)) MB"
Write-Host ""
Write-Host "To run: $releaseDir\rst.exe"
