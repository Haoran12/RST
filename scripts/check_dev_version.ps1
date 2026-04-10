$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml not found at $pubspecPath"
}

$versionLine = (Get-Content $pubspecPath | Where-Object { $_ -match '^\s*version:\s*' } | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($versionLine)) {
    throw "version field not found in pubspec.yaml"
}

$version = ($versionLine -replace '^\s*version:\s*', '').Trim()
$pattern = '^0\.1\.(\d+)\+(\d+)$'

if ($version -notmatch $pattern) {
    throw "Invalid version '$version'. Development stage requires '0.1.<patch>+<build>' (e.g. 0.1.7+23)."
}

$patch = [int]$matches[1]
$build = [int]$matches[2]
if ($patch -lt 0 -or $build -lt 1) {
    throw "Invalid version '$version'. Patch must be >= 0 and build must be >= 1."
}

Write-Host "OK: pubspec version '$version' matches development policy (0.1.xx)."
