param(
  [string]$Repo = "",
  [string]$Tag = "",
  [switch]$Restart
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Info([string]$Message) {
  Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
  Write-Host "[OK] $Message" -ForegroundColor Green
}

function Fail([string]$Message) {
  Write-Host "[ERROR] $Message" -ForegroundColor Red
  exit 1
}

function Get-WebHeaders {
  return @{
    "User-Agent" = "RST-Updater"
  }
}

function Read-Manifest([string]$ManifestPath) {
  if (-not (Test-Path $ManifestPath)) {
    return $null
  }
  return Get-Content $ManifestPath -Raw | ConvertFrom-Json
}

function Get-ManifestStringValue($Manifest, [string]$PropertyName) {
  if ($null -eq $Manifest) {
    return ""
  }

  $property = $Manifest.PSObject.Properties[$PropertyName]
  if ($null -eq $property) {
    return ""
  }

  if ($null -eq $property.Value) {
    return ""
  }

  return [string]$property.Value
}

function Resolve-LatestTagFromWeb([string]$Repo) {
  $headers = Get-WebHeaders
  $latestUri = "https://github.com/$Repo/releases/latest"

  try {
    $response = Invoke-WebRequest -Uri $latestUri -Headers $headers -MaximumRedirection 5
  } catch {
    Fail "Failed to query GitHub Release: $($_.Exception.Message)"
  }

  $finalUri = $response.BaseResponse.ResponseUri
  if ($null -eq $finalUri) {
    Fail "Failed to resolve latest GitHub Release URL."
  }

  $absoluteUri = [string]$finalUri.AbsoluteUri
  $match = [regex]::Match($absoluteUri, "/releases/tag/([^/?#]+)")
  if (-not $match.Success) {
    Fail "Failed to resolve latest GitHub Release tag from $absoluteUri"
  }

  return $match.Groups[1].Value
}

function Copy-DirectoryContent([string]$SourceDir, [string]$DestinationDir, [string[]]$ExcludedFiles) {
  if (-not (Test-Path $SourceDir)) {
    return
  }
  if (-not (Test-Path $DestinationDir)) {
    New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
  }

  $arguments = @(
    $SourceDir,
    $DestinationDir,
    "/E",
    "/R:2",
    "/W:1",
    "/NFL",
    "/NDL",
    "/NJH",
    "/NJS",
    "/NP"
  )

  if ($ExcludedFiles.Count -gt 0) {
    $arguments += "/XF"
    $arguments += $ExcludedFiles
  }

  $null = & robocopy @arguments
  if ($LASTEXITCODE -ge 8) {
    Fail "Failed to copy update content from $SourceDir"
  }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$manifestPath = Join-Path $installRoot "release-manifest.json"
$manifest = Read-Manifest -ManifestPath $manifestPath

if (-not $Repo) {
  $Repo = Get-ManifestStringValue -Manifest $manifest -PropertyName "repo"
}
if (-not $Repo) {
  Fail "Missing GitHub repo. Set it in release-manifest.json or pass -Repo owner/repo."
}

$currentVersion = Get-ManifestStringValue -Manifest $manifest -PropertyName "version"

Write-Info "Checking GitHub Release..."
$targetTag = if ($Tag) { $Tag } else { Resolve-LatestTagFromWeb -Repo $Repo }

if (-not $Tag -and $currentVersion -and $currentVersion -eq $targetTag) {
  Write-Ok "Already on latest version: $currentVersion"
  exit 0
}

$expectedAssetName = "RST-$targetTag-update.zip"
$assetDownloadUrl = "https://github.com/$Repo/releases/download/$targetTag/$expectedAssetName"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("rst-update-" + [guid]::NewGuid().ToString("N"))
$extractRoot = Join-Path $tempRoot "extract"
$zipPath = Join-Path $tempRoot $expectedAssetName
New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

Write-Info "Downloading $expectedAssetName..."
try {
  Invoke-WebRequest -Uri $assetDownloadUrl -Headers (Get-WebHeaders) -OutFile $zipPath
} catch {
  Fail "Failed to download update asset: $($_.Exception.Message)"
}

Write-Info "Extracting update package..."
Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force

$stopScript = Join-Path $installRoot "scripts\release_stop.vbs"
if (Test-Path $stopScript) {
  Write-Info "Stopping running RST process..."
  Start-Process -FilePath "wscript.exe" -ArgumentList ('"' + $stopScript + '"') -Wait
  Start-Sleep -Seconds 2
}

Write-Info "Applying update files..."
Copy-DirectoryContent -SourceDir (Join-Path $extractRoot "backend") -DestinationDir (Join-Path $installRoot "backend") -ExcludedFiles @()
Copy-DirectoryContent -SourceDir (Join-Path $extractRoot "frontend") -DestinationDir (Join-Path $installRoot "frontend") -ExcludedFiles @()
Copy-DirectoryContent -SourceDir (Join-Path $extractRoot "scripts") -DestinationDir (Join-Path $installRoot "scripts") -ExcludedFiles @()

$rootFiles = @(
  ".env.example",
  "apply-update.bat",
  "UPDATE.md",
  "release-manifest.json",
  "update.bat"
)
foreach ($file in $rootFiles) {
  $source = Join-Path $extractRoot $file
  if (Test-Path $source) {
    Copy-Item -Path $source -Destination (Join-Path $installRoot $file) -Force
  }
}

$setupScript = Join-Path $installRoot "scripts\setup_release.bat"
if (-not (Test-Path $setupScript)) {
  Fail "Missing scripts\setup_release.bat after update copy."
}

Write-Info "Refreshing locked runtime dependencies..."
$setupProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", ('"' + $setupScript + '"') -WorkingDirectory $installRoot -Wait -PassThru
if ($setupProcess.ExitCode -ne 0) {
  Fail "Update copied successfully, but runtime setup failed with exit code $($setupProcess.ExitCode). Existing data was preserved."
}

try {
  Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
} catch {
}

Write-Ok "Updated to GitHub Release $targetTag"

if ($Restart) {
  $startScript = Join-Path $installRoot "scripts\release_start.vbs"
  if (Test-Path $startScript) {
    Write-Info "Starting RST..."
    Start-Process -FilePath "wscript.exe" -ArgumentList ('"' + $startScript + '"')
  }
}
