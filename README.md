# RST MVP Scaffold

This repository is now bootstrapped for the `Flutter + Rust` MVP described in:

- `docs/implementation-plan.md`
- `docs/contracts.md`
- `docs/DESIGN.md`

## Current Phase

Phase 0 scaffold is in place:

- Flutter app shell with 4 tabs: `Chat`, `Lore`, `Settings`, `Log`
- Shared design-system style widgets and dark theme baseline
- `core/` split for bridge, providers, routing, and services
- Rust library crate under `rust/` with module skeleton:
  - `api`
  - `models`
  - `prompt`
  - `storage`
  - `retrieval`
  - `security`

## Run

```bash
flutter pub get
flutter run
```

## Verify

```bash
flutter analyze
flutter test
cargo check --manifest-path rust/Cargo.toml
pwsh ./scripts/check_dev_version.ps1
```

## Android Native Build Prerequisites

Android APK now auto-builds Rust native libraries during Gradle `preBuild` and packages `librst_core.so` for:

- `arm64-v8a`
- `armeabi-v7a`
- `x86_64`

One-time setup on a new machine:

```bash
cargo install cargo-ndk
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
```

## Android Release Packaging (Canonical Path)

Use the project packaging script so final APK output is always standardized:

```powershell
pwsh ./scripts/build_android_release.ps1
```

The packaging script automatically increments the `+build` number in `pubspec.yaml`,
builds the release APK with the new version, and prepends a release entry to
`docs/version-history.md`.

Final artifacts are placed in:

- `build/android/rst-<version>-release.apk`
- `build/android/rst-latest-release.apk`

## Generate FRB Bridge

```powershell
./scripts/generate_frb.ps1
```

This generates:

- `lib/core/bridge/frb_api.dart`
- `lib/core/bridge/frb_generated.dart`
- `lib/core/bridge/frb_generated.io.dart`
- `rust/src/frb_generated.rs`

## Recommended Next Step

Expand FRB APIs from `list/create/load session` to the remaining workspace contracts in `docs/contracts.md` (`rename/delete session`, `preset`, `api_config`, `world_book`).

## Android Update & Data Persistence

- App runtime data is now stored in app-private support directory: `<app_support>/rst_data`.
- On startup, Rust workspace is explicitly bound to that directory and will try to migrate legacy `./rust/data` once.
- Upgrading APK in-place (without uninstall) keeps this private data by Android design.

For upgrade installs to work reliably:

- Keep `applicationId` unchanged (`com.rst.app.rst`).
- Sign all release APKs with the same keystore.
- Increase `versionCode` for every release build.
- Development-stage app version must stay on `0.1.xx` (see `AGENTS.md`).

Release signing is configured via `android/key.properties`:

```properties
storeFile=../keystore/rst-release.jks
storePassword=***
keyAlias=***
keyPassword=***
# Optional but strongly recommended:
# signerSha256=<release certificate SHA-256 without colons>
# Optional only for intentionally preserving a historical debug-signed APK line:
# allowDebugCertificate=true
```

Important:

- `release` builds must never fall back to debug signing.
- If `android/key.properties` or the referenced keystore is missing, `flutter build apk --release` must fail.
- `scripts/build_android_release.ps1` now verifies the built APK certificate and rejects Android Debug signing unless the exact historical signer is explicitly pinned.
- Keep the real `android/key.properties` and release keystore outside version control; use `android/key.properties.example` as the template.
