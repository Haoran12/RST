# RST v0.2

Desktop-oriented full-stack app:
- Backend: FastAPI + uv
- Frontend: Vue 3 + Vite + pnpm

## Quick Start (Dev)

1. Install and bootstrap dependencies:
   - `scripts\\setup.bat`
2. Start backend + frontend dev servers:
   - `scripts\\dev.bat`
3. Open UI:
   - `http://localhost:15173`

## Release Mode (No Console Window)

1. Run release safety checks (secret leak guard):
   - `scripts\\release_check.bat`
2. Build frontend bundle:
   - `scripts\\release_build.bat`
3. Start app in background (no command window):
   - double-click `scripts\\release_start.vbs`
4. Stop background app:
   - double-click `scripts\\release_stop.vbs`

Release mode serves `frontend/dist` directly from backend on:
- `http://127.0.0.1:18080/`

## Security Notes

- Never commit `.env` or any `.env.*` (except `.env.example`).
- Never commit runtime data directories (`data/`, `_tmp_llm_import_data/`, `release/`).
- API keys are encrypted at rest in runtime data; encryption key stays local in `data/.keyfile` unless `RST_ENCRYPTION_KEY` is provided.
- Run `scripts\\release_check.bat` before tagging/pushing release.

## Suggested v0.2 GitHub Release Flow

1. `git add -A`
2. `git commit -m "release: v0.2"`
3. `git tag v0.2`
4. `git push origin <branch> --tags`

## Environment Variables

Start from `.env.example` and adjust only when needed.

Main runtime flags:
- `RST_BACKEND_PORT` (default `18080`)
- `RST_BACKEND_RELOAD` (`1` for dev hot reload, `0` for release)
- `RST_SERVE_FRONTEND` (`1` to serve built frontend from backend)
- `RST_FRONTEND_DIST` (default `./frontend/dist`)
