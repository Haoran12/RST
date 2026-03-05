# Release Checklist v0.2

## Pre-release

1. Ensure local `.env` exists and contains your runtime settings (do not commit it).
2. Run `scripts\\setup.bat`.
3. Run `scripts\\release_check.bat` and fix all failures.
4. Run tests as needed (`scripts\\test.bat`).

## Build and Verify

1. Run `scripts\\release_build.bat`.
2. Start with `scripts\\release_start.vbs`.
3. Verify app opens at `http://127.0.0.1:18080/`.
4. Stop with `scripts\\release_stop.vbs`.

## GitHub Push

1. `git status`
2. `git add -A`
3. `git commit -m "release: v0.2"`
4. `git tag v0.2`
5. `git push origin <branch> --tags`

## Release Asset Suggestions

- Source code zip (GitHub auto-generated)
- Optional packaged zip with:
  - `backend/`
  - `frontend/dist/`
  - `scripts/`
  - `.env.example`
  - `README.md`
