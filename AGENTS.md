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
