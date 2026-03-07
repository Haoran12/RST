# Release Checklist v0.3

## Pre-release

1. Ensure local `.env` exists and contains your runtime settings (do not commit it).
2. Run `scripts\\setup.bat`.
3. Run `scripts\\release_check.bat` and fix all failures.
4. Run tests as needed (`scripts\\test.bat`).

## Build and Verify

1. Run `scripts\\release_build.bat`.
2. Run `scripts\\release_package.bat`.
3. Run `scripts\\release_update_package.bat`.
4. Open `release\\RST-v0.3-quickstart\\` and verify these package-root files exist:
   - `setup.bat`
   - `start.vbs`
   - `stop.vbs`
   - `README-quickstart.md`
5. Open `release\\RST-v0.3-update\\` and verify these package-root files exist:
   - `apply-update.bat`
   - `update.bat`
   - `UPDATE.md`
6. Double-click `setup.bat` and confirm setup completes.
7. Double-click `start.vbs` and verify the app opens at `http://127.0.0.1:18080/`.
8. Double-click `stop.vbs` and verify the background process stops.

## GitHub Push

1. `git status`
2. `git add -A`
3. `git commit -m "release: v0.3"`
4. `git tag v0.3`
5. `git push origin <branch> --tags`

## GitHub Release

1. Set `GITHUB_TOKEN`
2. Run:
   `scripts\\release_publish.ps1 -Tag v0.3 -Title "RST v0.3" -NotesFile docs\\release-notes-v0.3.md -AssetPath release\\RST-v0.3-quickstart.zip,release\\RST-v0.3-update.zip`

## End-user Update Flow

1. Ask the user to stop RST.
2. Send `release\\RST-v0.3-update.zip`.
3. Tell the user to extract it into the existing install folder and overwrite packaged files only.
4. Tell the user to run `apply-update.bat`.
5. Confirm the user's `.env`, `data/`, and `logs/` remain in place.
6. Tell the user that future updates can use `update.bat` directly from GitHub.

