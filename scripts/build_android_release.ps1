param(
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$flutterOutputApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
$releaseDir = Join-Path $projectRoot "build\android"

if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml not found at $pubspecPath"
}

$versionLine = (Get-Content $pubspecPath | Where-Object { $_ -match '^\s*version:\s*' } | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($versionLine)) {
    throw "version field not found in pubspec.yaml"
}

$version = ($versionLine -replace '^\s*version:\s*', '').Trim()
if ($version -notmatch '^0\.1\.(\d+)\+(\d+)$') {
    throw "Invalid version '$version'. Development stage requires '0.1.<patch>+<build>'."
}

if (-not $SkipFlutterBuild) {
    Write-Host "Building release APK with Flutter..."
    flutter build apk --release
}

if (-not (Test-Path $flutterOutputApk)) {
    throw "Flutter release APK not found: $flutterOutputApk"
}

New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

$versionedApkName = "rst-$version-release.apk"
$versionedApkPath = Join-Path $releaseDir $versionedApkName
$latestApkPath = Join-Path $releaseDir "rst-latest-release.apk"

Copy-Item -LiteralPath $flutterOutputApk -Destination $versionedApkPath -Force
Copy-Item -LiteralPath $flutterOutputApk -Destination $latestApkPath -Force

$versionedFile = Get-Item $versionedApkPath

Write-Host ""
Write-Host "Release APK packaged successfully."
Write-Host "Version: $version"
Write-Host "Output (versioned): $($versionedFile.FullName)"
Write-Host "Output (latest): $latestApkPath"
Write-Host "Size: $([Math]::Round($versionedFile.Length / 1MB, 2)) MB"
