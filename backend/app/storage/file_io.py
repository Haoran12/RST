from __future__ import annotations

import json
import os
import shutil
import tempfile
import threading
import time
from pathlib import Path
from typing import Any

_locks: dict[str, threading.Lock] = {}
_locks_guard = threading.Lock()
_REPLACE_RETRIES = 10
_REPLACE_RETRY_BASE_DELAY_SECONDS = 0.02


def _get_lock(path: Path) -> threading.Lock:
    """Return a per-path lock guarded by a global lock."""
    key = str(path.resolve())
    with _locks_guard:
        lock = _locks.get(key)
        if lock is None:
            lock = threading.Lock()
            _locks[key] = lock
        return lock


def _replace_with_retry(source: Path, target: Path) -> None:
    """Retry replace to tolerate transient file locks on Windows."""
    for attempt in range(_REPLACE_RETRIES):
        try:
            os.replace(source, target)
            return
        except PermissionError:
            if attempt == _REPLACE_RETRIES - 1:
                raise
            time.sleep(_REPLACE_RETRY_BASE_DELAY_SECONDS * (attempt + 1))


def atomic_write(path: Path, data: bytes) -> None:
    """Write bytes atomically with a temp file and optional backup."""
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    backup_path = path.with_suffix(".bak")
    lock = _get_lock(path)
    tmp_path: Path | None = None

    with lock:
        try:
            fd, tmp_name = tempfile.mkstemp(
                dir=path.parent, prefix=f"{path.stem}.", suffix=".tmp"
            )
            tmp_path = Path(tmp_name)
            with os.fdopen(fd, "wb") as tmp_file:
                tmp_file.write(data)
                tmp_file.flush()
                os.fsync(tmp_file.fileno())
            if path.exists():
                shutil.copy2(path, backup_path)
            _replace_with_retry(tmp_path, path)
        except Exception:
            if tmp_path and tmp_path.exists():
                tmp_path.unlink()
            raise


def read_json(path: Path) -> dict[str, Any] | list[Any] | None:
    """Read JSON from path, returning None when missing."""
    if not path.exists():
        return None
    raw = path.read_text(encoding="utf-8")
    return json.loads(raw)


def write_json(path: Path, data: dict[str, Any] | list[Any]) -> None:
    """Serialize JSON with indentation and write atomically."""
    payload = json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8")
    atomic_write(path, payload)
