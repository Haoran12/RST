# Release Checklist v0.3

## Pre-release

1. Ensure local `.env` exists and contains your runtime settings (do not commit it).
2. Run `scripts\\setup.bat`.
3. Run `scripts\\release_check.bat` and fix all failures.
4. Run tests as needed (`scripts\\test.bat`).

## Build and Verify

1. Run `scripts\\release_build.bat`.
2. Run `scripts\\release_package.bat`.
3. Open `release\\RST-v0.3-quickstart\\` and verify these package-root files exist:
   - `01-安装部署.bat`
   - `02-启动RST.vbs`
   - `03-关闭RST.vbs`
   - `README-快速开始.md`
4. Double-click `01-安装部署.bat` and confirm setup completes.
5. Double-click `02-启动RST.vbs` and verify the app opens at `http://127.0.0.1:18080/`.
6. Double-click `03-关闭RST.vbs` and verify the background process stops.

## GitHub Push

1. `git status`
2. `git add -A`
3. `git commit -m "release: v0.3"`
4. `git tag v0.3`
5. `git push origin <branch> --tags`

## GitHub Release

1. Set `GITHUB_TOKEN`
2. Run:
   `scripts\\release_publish.ps1 -Tag v0.3 -Title "RST v0.3" -NotesFile docs\\release-notes-v0.3.md -AssetPath release\\RST-v0.3-quickstart.zip`