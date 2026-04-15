# RST Repository Working Rules

## Versioning (Development Stage)

- During development, app version **must** use `0.1.xx` semantics.
- In `pubspec.yaml`, this means:
  - `version` must match `0.1.<patch>+<build>`
  - Example: `0.1.7+23`
- Do not switch to `1.x` or other minor lines unless explicitly requested by the project owner.

## Release Compatibility Reminder

- Keep Android `applicationId` unchanged to support in-place APK upgrade.
- Keep signing key stable across releases.
- Increase `versionCode` (`+build` in pubspec) for every release.

## Build Output And Version Tracking

- Development-stage versioning remains unified on `0.1.xx` and must not drift to other minor lines without owner approval.
- Every packaged build artifact filename must include the full app version (recommended: `0.1.<patch>+<build>` or equivalent normalized form).
- Canonical Android APK output directory is **`<repo>/build/android`**.
- Do not treat `build/app/outputs/flutter-apk/` as final delivery path; it is only Flutter's intermediate output.
- Standard packaging command: `pwsh ./scripts/build_android_release.ps1`.
- The project must maintain a persistent released-version record (for example in `docs/version-history.md` or `CHANGELOG.md`) and update it for each release.
- The build process must include version bump capability: at minimum, increment `+build` on each build/release and write back the updated version metadata.

## UI Copy And Editor UX

- Keep UI copy minimal, especially in editing screens and config panels.
- Do not add explanatory filler text, reassurance copy, or status copy unless it directly helps the user complete the current task.
- Avoid messages such as "content auto-saved", "quotes/brackets normal", or similar low-value helper text by default.
- Prefer in-editor visual feedback over extra prose when showing validation or structure hints.
- When the user explicitly asks for less copy or less clutter, that preference overrides any stylistic tendency or skill guidance.
- Skills may inform layout or implementation quality, but they must not be used as a reason to add unnecessary UI copy.
