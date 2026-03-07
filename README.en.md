# RST v0.3

A desktop-oriented local roleplay/long-context assistant focused on stronger context consistency, configurable prompt assembly, and structured lore/state management.

## Highlights

1. Session and message management
- Create, switch, rename, and delete sessions.
- Edit or delete messages and control message visibility for prompt assembly.

2. Preset-driven prompt assembly
- Configurable prompt items and ordering.
- Built for quick switching between different play styles.

3. RST Lore and state tracking
- Structured lore management and context-based retrieval/injection.
- Designed for long conversations with evolving world and character states.

4. Dual API configuration
- Separate main chat API and scheduler API.
- Provider, model, and parameter configuration with model list fetching support.

5. Local-first security
- API keys are encrypted at rest locally.
- Includes pre-release safety checks to reduce accidental secret leakage.

## Tech Stack

- Backend: FastAPI + uv
- Frontend: Vue 3 + Vite + pnpm
- Storage: local project data, with SQLite used as the canonical lore/runtime store for new sessions

## Install (Windows)

### Requirements

- Windows 10/11
- Python 3.12+
- Node.js 18+

> `scripts\\setup.bat` checks required tools, tries to bootstrap missing dependencies, and installs project dependencies.

### Steps

```bat
git clone https://github.com/Haoran12/RST.git
cd RST
scripts\setup.bat
```

## Run

### Dev mode

```bat
scripts\dev.bat
```

- Frontend: `http://localhost:15173`
- Backend health: `http://127.0.0.1:18080/health`

### Release mode (no console window)

```bat
scripts\release_check.bat
scripts\release_build.bat
```

Then double-click:
- Start: `scripts\release_start.vbs`
- Stop: `scripts\release_stop.vbs`

Open the app at: `http://127.0.0.1:18080/`

### Quickstart package (distributable zip)

Build a release zip in `release/`:

```bat
scripts\release_package.bat
```

This creates:
- Folder: `release\RST-v0.3-quickstart\`
- Zip: `release\RST-v0.3-quickstart.zip`

After extracting the packaged zip, the package root clearly exposes these entry files:
- `setup.bat` — install or update the runtime dependencies
- `start.vbs` — start RST in the background and open the browser
- `stop.vbs` — stop the background RST process
- `QUICKSTART.md` — quick usage notes

Recommended order for end users:
1. Run `setup.bat`
2. Run `start.vbs`
3. Run `stop.vbs` when finished

Advanced scripts remain available under `scripts/`.

### Publish to GitHub Release

If you want to update the GitHub Release and upload the packaged zip:

```powershell
$env:GITHUB_TOKEN = "<github-token>"
scripts\release_publish.ps1 -Tag v0.3 -Title "RST v0.3" -NotesFile docs\release-notes-v0.3.md -AssetPath release\RST-v0.3-quickstart.zip
```

Notes:
- `GITHUB_TOKEN` must have permission to create or edit releases.
- The script updates the release notes for the tag if the release already exists.
- If `-AssetPath` is omitted, the script defaults to `release\RST-v0.3-quickstart.zip`.

## Security Notes

- Do not commit `.env` or `.env.*` (except `.env.example`).
- Do not commit runtime or local data (`data/`, `_tmp_llm_import_data/`, `release/`).
- Run `scripts\\release_check.bat` before packaging or publishing.
