$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$rustRoot = Join-Path $projectRoot "rust"
$dartOutput = Join-Path $projectRoot "lib/core/bridge"
$rustOutput = "\\?\$projectRoot\rust\src\frb_generated.rs"

& flutter_rust_bridge_codegen generate `
  -r crate::frb_api `
  -d $dartOutput `
  --rust-root $rustRoot `
  --rust-output $rustOutput `
  --dart-entrypoint-class-name RustCore `
  --no-web
