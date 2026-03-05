# RST v0.2

## Highlights
- Added release mode that serves built frontend from backend for simpler deployment.
- Added no-console startup and shutdown scripts for Windows desktop usage.
- Improved first-time setup flow with automatic dependency bootstrap attempts.
- Added release safety checks to reduce risk of secret or local runtime data leakage.

## Security
- Expanded `.gitignore` coverage for local runtime and temporary import data.
- Removed tracked `_tmp_llm_import_data/` from repository history onward.
- Added pre-release scanner for accidental tracked `.env` files and secret-like tokens.

## Runtime and DX
- Backend now supports `RST_BACKEND_RELOAD` and `RST_SERVE_FRONTEND` toggles.
- Frontend production API base defaults to same-origin for release mode.
- Added build/check/run helper scripts for release workflow.

## Verification
- Release safety check script passed.
- Frontend production build passed.
- Core backend tests passed (`test_health.py`, `test_encryption.py`).
