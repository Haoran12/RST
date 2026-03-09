# RST v0.3

## Highlights
- Improved the release package UX with clear package-root entry scripts after unzip.
- Added `setup.bat`, `start.vbs`, and `stop.vbs` to the packaged release root.
- Kept advanced runtime helpers under `scripts/` while exposing a simpler end-user path.

## Runtime Improvements
- Updated `release_quick_start.bat` to launch the background start flow instead of blocking in a console.
- Improved `release_start.vbs` to record a PID file and write stdout/stderr logs under `logs/`.

- Fixed production frontend API resolution so release builds default to same-origin instead of baking in a machine-specific localhost API base.

## Patch Updates
- Improved the RST Lores scheduler prompt template editing UX by moving full template editing into a larger overlay.
- Kept the scheduler panel compact with prompt summary cards, while exposing runtime variables and format constraints in the overlay.
- Added unsaved-change guards and save-success feedback for scheduler prompt templates, including tab-switch and session-switch interception.

## Documentation
- Updated `README.md`, `README.en.md`, and `README.zh-CN.md` for the v0.3 release flow.
- Documented the packaged release entry scripts and the GitHub Release publishing command.

## Verification
- Release safety check passed.
- Frontend production build passed.
- Release package generation passed.
- GitHub Release asset upload completed.
