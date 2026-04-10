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
- The project must maintain a persistent released-version record (for example in `docs/version-history.md` or `CHANGELOG.md`) and update it for each release.
- The build process must include version bump capability: at minimum, increment `+build` on each build/release and write back the updated version metadata.
