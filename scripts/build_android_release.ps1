param(
    [switch]$SkipFlutterBuild,
    [string]$ReleaseNotes = "Release packaging build for current workspace state."
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$mainManifestPath = Join-Path $projectRoot "android\app\src\main\AndroidManifest.xml"
$versionHistoryPath = Join-Path $projectRoot "docs\version-history.md"
$flutterOutputApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
$releaseDir = Join-Path $projectRoot "build\android"

if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml not found at $pubspecPath"
}
if (-not (Test-Path $mainManifestPath)) {
    throw "AndroidManifest.xml not found at $mainManifestPath"
}

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

$manifestRaw = Get-Content $mainManifestPath -Raw
if ($manifestRaw -notmatch '<uses-permission\s+android:name="android\.permission\.INTERNET"\s*/?>') {
    throw "android.permission.INTERNET is missing in main AndroidManifest.xml. Release builds require network permission."
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
    Write-Host "Version bump: $currentVersion -> $version"

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

    $releaseDate = Get-Date -Format "yyyy-MM-dd"
    $historyEntryLines = @(
        "## $version ($releaseDate)",
        "",
        "- Build type: Android APK release",
        "- Artifact: ``$versionedApkName``",
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

    $versionedFile = Get-Item $versionedApkPath
    $shouldRestorePubspec = $false

    Write-Host ""
    Write-Host "Release APK packaged successfully."
    Write-Host "Version: $version"
    Write-Host "Output (versioned): $($versionedFile.FullName)"
    Write-Host "Output (latest): $latestApkPath"
    Write-Host "Size: $([Math]::Round($versionedFile.Length / 1MB, 2)) MB"
}
catch {
    if ($shouldRestorePubspec) {
        Set-Content -Path $pubspecPath -Value $originalPubspecLines
        Write-Warning "Build failed. Restored pubspec.yaml to $currentVersion."
    }
    throw
}
