# Release Update Workflow

## Goal

Ship fixes to existing release users without touching their runtime data.

The update strategy is:
- distribute a dedicated update zip via GitHub Release
- embed a local GitHub updater script in the installed package
- exclude user-owned runtime state from the zip
- rerun locked backend dependency sync after files are replaced

## Runtime data that must be preserved

Do not overwrite or delete these paths in an existing install:
- `.env`
- `data/`
- `logs/`
- `backend/.venv/`

## Maintainer workflow

1. Build the normal frontend bundle:
   - `scripts\release_build.bat`
2. Build the full quickstart package:
   - `scripts\release_package.bat`
3. Build the update package:
   - `scripts\release_update_package.bat`
4. Upload one or both assets to GitHub Release:
   - `scripts\release_publish.ps1 -Tag v0.3 -Title "RST v0.3" -NotesFile docs\release-notes-v0.3.md -AssetPath release\RST-v0.3-quickstart.zip,release\RST-v0.3-update.zip`

## End-user workflow

### First update for existing users

1. Stop RST.
2. Extract `RST-v0.3-update.zip` into the existing installation folder.
3. Allow Windows to overwrite the packaged application files.
4. Run `apply-update.bat` from the install root.
5. Start RST again.

### Future updates from GitHub

After the first update, users can update directly from GitHub Release:

1. Close RST.
2. Run `update.bat` in the install root.
3. The script checks GitHub Release, downloads the latest `RST-*-update.zip`, applies it, and refreshes locked dependencies.
4. Start RST again if it does not auto-restart.

## Why this is safe

- The update zip contains only application code, frontend build output, and runtime scripts.
- The update zip does not contain `.env`, `data/`, `logs/`, or `backend/.venv/`.
- `apply-update.bat` reruns `scripts\setup_release.bat`, which refreshes locked backend dependencies without deleting user data.

## Recommended support message to users

You can send the following instructions:

1. If this is your first patch on v0.3, close RST, extract the update zip into your current RST folder, and run `apply-update.bat`.
2. After that, you can use `update.bat` for future GitHub-based updates.

This update keeps your existing configuration and session data because it does not replace `.env` or `data/`.
