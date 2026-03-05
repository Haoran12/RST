$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

$failed = $false

function Write-Ok([string]$Message) {
  Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Fail([string]$Message) {
  Write-Host "[FAIL] $Message" -ForegroundColor Red
  $script:failed = $true
}

$trackedFiles = git ls-files
if ($LASTEXITCODE -ne 0) {
  throw "git ls-files failed"
}

$trackedEnv = @($trackedFiles | Where-Object {
    ($_ -eq ".env") -or (($_ -like ".env.*") -and ($_ -ne ".env.example"))
  })
if ($trackedEnv.Count -gt 0) {
  Write-Fail ("Tracked env files detected: " + ($trackedEnv -join ", "))
} else {
  Write-Ok "No tracked .env files."
}

$forbiddenPrefixes = @("_tmp_llm_import_data/", "data/", "release/")
$badTracked = @(
  foreach ($file in $trackedFiles) {
    foreach ($prefix in $forbiddenPrefixes) {
      if ($file.StartsWith($prefix)) {
        $file
        break
      }
    }
  }
) | Select-Object -Unique
if ($badTracked.Count -gt 0) {
  Write-Fail ("Local/runtime files tracked: " + ($badTracked -join ", "))
} else {
  Write-Ok "No tracked local/runtime directories."
}

$secretPattern = "(sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z\\-_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{20,}|ghp_[A-Za-z0-9]{30,})"
$scanOutput = git grep -n -I -E $secretPattern -- . ":!backend/tests/*" ":!frontend/tests/*"
if ($LASTEXITCODE -eq 0 -and $scanOutput) {
  Write-Fail "Possible secret-like tokens found in tracked files:"
  Write-Host $scanOutput
} elseif ($LASTEXITCODE -gt 1) {
  Write-Fail "git grep secret scan failed."
} else {
  Write-Ok "No obvious secret-like tokens in tracked files."
}

if ($failed) {
  Write-Host "`nRelease safety check failed." -ForegroundColor Red
  exit 1
}

Write-Host "`nRelease safety check passed." -ForegroundColor Green
