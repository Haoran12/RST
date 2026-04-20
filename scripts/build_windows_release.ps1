param(
    [switch]$SkipFlutterBuild,
    [string]$ReleaseNotes = "Windows x64 release build."
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$versionHistoryPath = Join-Path $projectRoot "docs\version-history.md"
$rustDir = Join-Path $projectRoot "rust"
$rustDllPath = Join-Path $rustDir "target\release\rst_core.dll"
$flutterOutputDir = Join-Path $projectRoot "build\windows\x64\runner\Release"
$releaseDir = Join-Path $projectRoot "build\Win64"

if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml not found at $pubspecPath"
}

# Parse version from pubspec.yaml
$pubspecLines = Get-Content $pubspecPath
$versionLineIndex = -1
for ($i = 0; $i -lt $pubspecLines.Count; $i++) {
    if ($pubspecLines[$i] -match '^\s*version:\s*') {
        $versionLineIndex = $i
        break
    }
}

if ($versionLineIndex -lt 0) {
    throw "version field not found in pubspec.yaml"
}

$currentVersion = ($pubspecLines[$versionLineIndex] -replace '^\s*version:\s*', '').Trim()
$versionMatch = [regex]::Match($currentVersion, '^0\.1\.(\d+)\+(\d+)$')
if (-not $versionMatch.Success) {
    throw "Invalid version '$currentVersion'. Development stage requires '0.1.<patch>+<build>'."
}

$patch = [int]$versionMatch.Groups[1].Value
$currentBuild = [int]$versionMatch.Groups[2].Value
$nextBuild = $currentBuild + 1
$version = "0.1.{0}+{1}" -f $patch, $nextBuild

$originalPubspecLines = @($pubspecLines)
$pubspecLines[$versionLineIndex] = "version: $version"
Set-Content -Path $pubspecPath -Value $pubspecLines
$shouldRestorePubspec = $true

try {
    Write-Host "Version bump: $currentVersion -> $version" -ForegroundColor Cyan

    # Step 1: Build Rust library
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

    # Step 2: Build Flutter Windows app
    if (-not $SkipFlutterBuild) {
        Write-Host "Building Flutter Windows application..." -ForegroundColor Yellow
        Push-Location $projectRoot
        try {
            flutter build windows --release
            Write-Host "Flutter application built successfully." -ForegroundColor Green
        }
        finally {
            Pop-Location
        }
    }

    if (-not (Test-Path $flutterOutputDir)) {
        throw "Flutter Windows output not found: $flutterOutputDir"
    }

    # Step 3: Copy Rust DLL to Flutter output
    Write-Host "Copying Rust DLL..." -ForegroundColor Yellow
    Copy-Item -Path $rustDllPath -Destination $flutterOutputDir -Force

    # Step 4: Create release package
    Write-Host "Creating release package..." -ForegroundColor Yellow

    # Always create fresh directory
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

    # Copy all files from Flutter output
    Get-ChildItem -Path $flutterOutputDir | ForEach-Object {
        $destPath = Join-Path $releaseDir $_.Name
        if (Test-Path $destPath) {
            Remove-Item -Path $destPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        Copy-Item -Path $_.FullName -Destination $releaseDir -Recurse -Force
    }

    # Create versioned zip archive
    $versionedZipName = "rst-$version-win64.zip"
    $versionedZipPath = Join-Path $projectRoot "build\$versionedZipName"
    if (Test-Path $versionedZipPath) {
        Remove-Item -Path $versionedZipPath -Force
    }
    Compress-Archive -Path $releaseDir -DestinationPath $versionedZipPath -CompressionLevel Optimal

    # Create latest zip archive
    $latestZipPath = Join-Path $projectRoot "build\rst-latest-win64.zip"
    if (Test-Path $latestZipPath) {
        Remove-Item -Path $latestZipPath -Force
    }
    Copy-Item -Path $versionedZipPath -Destination $latestZipPath -Force

    # Step 5: Update version history
    $releaseDate = Get-Date -Format "yyyy-MM-dd"
    $historyEntryLines = @(
        "## $version ($releaseDate)",
        "",
        "- Build type: Windows x64 release",
        "- Artifact: ``$versionedZipName``",
        "- Notes: $ReleaseNotes"
    )
    $historyEntry = $historyEntryLines -join [Environment]::NewLine

    if (Test-Path $versionHistoryPath) {
        $existingHistory = Get-Content $versionHistoryPath -Raw
        if ($existingHistory -match '^(# Version History)(\r?\n)*') {
            $header = $Matches[1]
            $body = $existingHistory.Substring($Matches[0].Length).TrimStart("`r", "`n")
            $newHistory = $header + [Environment]::NewLine + [Environment]::NewLine + $historyEntry
            if (-not [string]::IsNullOrWhiteSpace($body)) {
                $newHistory += [Environment]::NewLine + [Environment]::NewLine + $body
            }
            Set-Content -Path $versionHistoryPath -Value $newHistory
        } else {
            $newHistory = $historyEntry + [Environment]::NewLine + [Environment]::NewLine + $existingHistory.TrimStart("`r", "`n")
            Set-Content -Path $versionHistoryPath -Value $newHistory
        }
    } else {
        $newHistory = "# Version History" + [Environment]::NewLine + [Environment]::NewLine + $historyEntry
        Set-Content -Path $versionHistoryPath -Value $newHistory
    }

    $shouldRestorePubspec = $false

    # Calculate total size
    $totalSize = (Get-ChildItem -Path $releaseDir -Recurse | Measure-Object -Property Length -Sum).Sum
    $zipFile = Get-Item $versionedZipPath

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Windows x64 release build completed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Version: $version"
    Write-Host "Output directory: $releaseDir"
    Write-Host "Total size: $([Math]::Round($totalSize / 1MB, 1)) MB"
    Write-Host ""
    Write-Host "Artifacts:" -ForegroundColor Cyan
    Write-Host "  - $versionedZipPath"
    Write-Host "    Size: $([Math]::Round($zipFile.Length / 1MB, 2)) MB"
    Write-Host "  - $latestZipPath"
}
catch {
    if ($shouldRestorePubspec) {
        Set-Content -Path $pubspecPath -Value $originalPubspecLines
        Write-Warning "Build failed. Restored pubspec.yaml to $currentVersion."
    }
    throw
}
