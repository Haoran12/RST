# RST v0.3

## Highlights
- Improved the release package UX with clear package-root entry scripts after unzip.
- Added `01-安装部署.bat`, `02-启动RST.vbs`, and `03-关闭RST.vbs` to the packaged release root.
- Kept advanced runtime helpers under `scripts/` while exposing a simpler end-user path.

## Runtime Improvements
- Updated `release_quick_start.bat` to launch the background start flow instead of blocking in a console.
- Improved `release_start.vbs` to record a PID file and write stdout/stderr logs under `logs/`.
- Improved `release_stop.vbs` to stop the recorded background process first, with port-based fallback cleanup.

## Documentation
- Updated `README.md`, `README.en.md`, and `README.zh-CN.md` for the v0.3 release flow.
- Documented the packaged release entry scripts and the GitHub Release publishing command.

## Verification
- Release safety check passed.
- Frontend production build passed.
- Release package generation passed.
- GitHub Release asset upload completed.