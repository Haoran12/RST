param(
    [switch]$SkipFlutterBuild,
    [string]$ReleaseNotes = "Release packaging build for current workspace state."
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$androidDir = Join-Path $projectRoot "android"
$androidKeyPropertiesPath = Join-Path $androidDir "key.properties"
$mainManifestPath = Join-Path $projectRoot "android\app\src\main\AndroidManifest.xml"
$versionHistoryPath = Join-Path $projectRoot "docs\version-history.md"
$flutterOutputApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
$releaseDir = Join-Path $projectRoot "build\Android"

if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml not found at $pubspecPath"
}
if (-not (Test-Path $mainManifestPath)) {
    throw "AndroidManifest.xml not found at $mainManifestPath"
}

function Read-PropertiesFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Properties file not found: $Path"
    }

    $map = @{}
    foreach ($line in Get-Content $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }
        $parts = $trimmed -split '=', 2
        if ($parts.Count -ne 2) {
            continue
        }
        $map[$parts[0].Trim()] = $parts[1].Trim()
    }

    return $map
}

function Get-KeyProperties {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Release signing config missing: $Path. Refusing to build a debug-signed release APK."
    }

    $map = Read-PropertiesFile -Path $Path

    foreach ($requiredKey in @('storeFile', 'storePassword', 'keyAlias', 'keyPassword')) {
        if (-not $map.ContainsKey($requiredKey) -or [string]::IsNullOrWhiteSpace($map[$requiredKey])) {
            throw "Release signing config '$requiredKey' is missing in $Path."
        }
    }

    return $map
}

function Resolve-StoreFilePath {
    param(
        [string]$BaseDir,
        [string]$RelativeOrAbsolutePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativeOrAbsolutePath)) {
        return $RelativeOrAbsolutePath
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BaseDir $RelativeOrAbsolutePath))
}

function Get-ApkSignerPath {
    param([string]$AndroidSdkDir)

    $buildToolsDir = Join-Path $AndroidSdkDir "build-tools"
    if (-not (Test-Path $buildToolsDir)) {
        throw "Android build-tools directory not found: $buildToolsDir"
    }

    $candidate = Get-ChildItem -Path $buildToolsDir -Directory |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName "apksigner.bat" } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace($candidate)) {
        throw "apksigner.bat not found under $buildToolsDir"
    }

    return $candidate
}

function Assert-ReleaseApkSignature {
    param(
        [string]$ApkPath,
        [string]$ApkSignerPath,
        [hashtable]$KeyProperties
    )

    $output = & $ApkSignerPath verify --print-certs $ApkPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "apksigner verification failed for $ApkPath`n$output"
    }

    $joined = ($output | Out-String)
    $actualSha256 = $null
    $certificateDn = $null
    foreach ($line in $output) {
        if ($line -match 'certificate SHA-256 digest:\s*([0-9a-fA-F:]+)') {
            $actualSha256 = $Matches[1].Trim().ToLower().Replace(':', '')
        }
        elseif ($line -match 'certificate DN:\s*(.+)$') {
            $certificateDn = $Matches[1].Trim()
        }
    }
    if ([string]::IsNullOrWhiteSpace($actualSha256)) {
        throw "Unable to read APK signer SHA-256 digest from apksigner output.`n$joined"
    }

    $expectedSha256 = $null
    if ($KeyProperties.ContainsKey('signerSha256')) {
        $expectedSha256 = $KeyProperties['signerSha256'].ToString().Trim().ToLower().Replace(':', '')
    }
    $allowDebugCertificate = $false
    if ($KeyProperties.ContainsKey('allowDebugCertificate')) {
        $allowDebugCertificate = $KeyProperties['allowDebugCertificate'].ToString().Trim().ToLower() -eq 'true'
    }
    if ($allowDebugCertificate -and [string]::IsNullOrWhiteSpace($expectedSha256)) {
        throw "allowDebugCertificate=true requires signerSha256 to be set in android/key.properties."
    }

    $usesAndroidDebugCertificate = -not [string]::IsNullOrWhiteSpace($certificateDn) -and $certificateDn -match 'CN=Android Debug'
    if ($usesAndroidDebugCertificate -and -not $allowDebugCertificate) {
        throw "APK is signed with Android Debug certificate. Only an explicitly pinned legacy signer may bypass this check.`n$joined"
    }
    if (-not [string]::IsNullOrWhiteSpace($expectedSha256) -and $actualSha256 -ne $expectedSha256) {
        throw "APK signer SHA-256 mismatch. Expected $expectedSha256 but got $actualSha256."
    }
}

$keyProperties = Get-KeyProperties -Path $androidKeyPropertiesPath
$storeFilePath = Resolve-StoreFilePath -BaseDir $androidDir -RelativeOrAbsolutePath $keyProperties['storeFile']
if (-not (Test-Path $storeFilePath)) {
    throw "Release keystore not found: $storeFilePath"
}

$localPropertiesPath = Join-Path $androidDir "local.properties"
if (-not (Test-Path $localPropertiesPath)) {
    throw "android/local.properties not found at $localPropertiesPath"
}
$localProperties = Read-PropertiesFile -Path $localPropertiesPath
if (-not $localProperties.ContainsKey('sdk.dir') -or [string]::IsNullOrWhiteSpace($localProperties['sdk.dir'])) {
    throw "sdk.dir is missing in $localPropertiesPath"
}
$androidSdkDir = $localProperties['sdk.dir']
$apkSignerPath = Get-ApkSignerPath -AndroidSdkDir $androidSdkDir

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

    Assert-ReleaseApkSignature -ApkPath $flutterOutputApk -ApkSignerPath $apkSignerPath -KeyProperties $keyProperties

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
