from __future__ import annotations

import json
import shutil
import threading
from pathlib import Path
from typing import Any

_locks: dict[str, threading.Lock] = {}
_locks_guard = threading.Lock()


def _get_lock(path: Path) -> threading.Lock:
    """Return a per-path lock guarded by a global lock."""
    key = str(path.resolve())
    with _locks_guard:
        lock = _locks.get(key)
        if lock is None:
            lock = threading.Lock()
            _locks[key] = lock
        return lock


def atomic_write(path: Path, data: bytes) -> None:
    """Write bytes atomically with a temp file and optional backup."""
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_suffix(".tmp")
    backup_path = path.with_suffix(".bak")
    lock = _get_lock(path)

    with lock:
        try:
            tmp_path.write_bytes(data)
            if path.exists():
                shutil.copy2(path, backup_path)
            tmp_path.replace(path)
        except Exception:
            if tmp_path.exists():
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
