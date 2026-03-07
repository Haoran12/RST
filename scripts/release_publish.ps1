param(
  [string]$Tag = "v0.3",
  [string]$Title = "RST v0.3",
  [string]$NotesFile = "docs/release-notes-v0.3.md",
  [string[]]$AssetPath,
  [switch]$Draft,
  [switch]$Prerelease
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
  Write-Host "[ERROR] $Message" -ForegroundColor Red
  exit 1
}

function Write-Info([string]$Message) {
  Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Resolve-AssetPath([string]$Path, [string]$RepoRoot) {
  if ([string]::IsNullOrWhiteSpace($Path)) {
    Fail "Asset path cannot be empty."
  }
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }
  return (Join-Path $RepoRoot $Path)
}

if (-not $env:GITHUB_TOKEN) {
  Fail "GITHUB_TOKEN is not set in current shell."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

if (-not (Test-Path $NotesFile)) {
  Fail "Notes file not found: $NotesFile"
}

$originUrl = git remote get-url origin
if ($LASTEXITCODE -ne 0 -or -not $originUrl) {
  Fail "Failed to read git origin URL."
}

$repoSlug = $null
if ($originUrl -match "github\.com[:/](.+?)(?:\.git)?$") {
  $repoSlug = $Matches[1]
}
if (-not $repoSlug) {
  Fail "Cannot parse owner/repo from origin URL: $originUrl"
}

$resolvedNotesFile = (Resolve-Path $NotesFile).Path
$notes = [System.IO.File]::ReadAllText($resolvedNotesFile, [System.Text.UTF8Encoding]::new($false))
$apiBase = "https://api.github.com/repos/$repoSlug"
$headers = @{
  Authorization = "Bearer $($env:GITHUB_TOKEN)"
  Accept = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2022-11-28"
}

$existing = $null
try {
  $existing = Invoke-RestMethod -Method Get -Uri "$apiBase/releases/tags/$Tag" -Headers $headers
} catch {
  if (-not $_.Exception.Response -or $_.Exception.Response.StatusCode.value__ -ne 404) {
    throw
  }
}

if ($existing) {
  $body = @{
    tag_name = $Tag
    name = $Title
    body = $notes
    draft = [bool]$Draft
    prerelease = [bool]$Prerelease
  } | ConvertTo-Json

  $updated = Invoke-RestMethod -Method Patch -Uri "$apiBase/releases/$($existing.id)" -Headers $headers -Body $body
  $release = $updated
  Write-Info "Updated release: $($release.html_url)"
} else {
  $createBody = @{
    tag_name = $Tag
    target_commitish = (git rev-parse --abbrev-ref HEAD)
    name = $Title
    body = $notes
    draft = [bool]$Draft
    prerelease = [bool]$Prerelease
  } | ConvertTo-Json

  $release = Invoke-RestMethod -Method Post -Uri "$apiBase/releases" -Headers $headers -Body $createBody
  Write-Info "Created release: $($release.html_url)"
}

if (-not $AssetPath -or $AssetPath.Count -eq 0) {
  $AssetPath = @("release/RST-$Tag-quickstart.zip")
}

$uploadUrl = $release.upload_url
if (-not $uploadUrl) {
  Fail "Release upload URL missing from GitHub API response."
}

$uploadBase = $uploadUrl -replace "\{\?name,label\}$", ""
$escapedAssetName = [System.Uri]::EscapeDataString($assetName)
$uploadHeaders = @{
  Authorization = "Bearer $($env:GITHUB_TOKEN)"
  Accept = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2022-11-28"
}

foreach ($asset in $AssetPath) {
  $resolvedAsset = Resolve-AssetPath -Path $asset -RepoRoot $repoRoot
  if (-not (Test-Path $resolvedAsset)) {
    Fail "Release asset not found: $asset"
  }

  $assetName = Split-Path -Path $resolvedAsset -Leaf
  $currentAsset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
  if ($currentAsset) {
    Write-Info "Deleting existing asset: $assetName"
    Invoke-RestMethod -Method Delete -Uri "$apiBase/releases/assets/$($currentAsset.id)" -Headers $headers | Out-Null
  }

  $escapedAssetName = [System.Uri]::EscapeDataString($assetName)
  Write-Info "Uploading asset: $assetName"
  $uploadedAsset = Invoke-RestMethod `
    -Method Post `
    -Uri "${uploadBase}?name=$escapedAssetName" `
    -Headers $uploadHeaders `
    -InFile $resolvedAsset `
    -ContentType "application/zip"

  Write-Host "[OK] Asset URL: $($uploadedAsset.browser_download_url)" -ForegroundColor Green
}

Write-Host "[OK] Release URL: $($release.html_url)" -ForegroundColor Green
