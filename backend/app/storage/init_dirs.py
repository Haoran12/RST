from __future__ import annotations

from pathlib import Path
import logging

from app.config import settings

logger = logging.getLogger(__name__)

REQUIRED_SUBDIRS = [
    "sessions",
    "presets",
    "api_configs",
    "appearance",
]


def ensure_data_dirs() -> Path:
    # Create the root data directory and required subdirectories
    data_root = settings.data_path
    for name in REQUIRED_SUBDIRS:
        (data_root / name).mkdir(parents=True, exist_ok=True)
    logger.info("Data directory ensured at %s", data_root)
    return data_root
