from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
DATA_DIR = REPO_ROOT / "data"

DATA_SUBDIRS = [
    DATA_DIR / "sessions",
    DATA_DIR / "presets",
    DATA_DIR / "api_configs",
    DATA_DIR / "appearance",
]


def ensure_data_dirs() -> None:
    for path in DATA_SUBDIRS:
        path.mkdir(parents=True, exist_ok=True)
