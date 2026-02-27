from __future__ import annotations

import shutil
from datetime import datetime
from pathlib import Path

from app.config import settings
from app.models.session import (
    SessionCreate,
    SessionMeta,
    SessionRename,
    SessionResponse,
    SessionSummary,
    SessionUpdate,
)
from app.storage.file_io import read_json, write_json


class SessionNotFoundError(RuntimeError):
    def __init__(self, name: str) -> None:
        super().__init__(f"Session '{name}' not found")
        self.name = name


class SessionNameExistsError(RuntimeError):
    def __init__(self, name: str) -> None:
        super().__init__(f"Session name '{name}' already exists")
        self.name = name


def _sessions_dir() -> Path:
    return settings.data_path / "sessions"


def _session_dir(name: str) -> Path:
    return _sessions_dir() / name


def _session_meta_path(name: str) -> Path:
    return _session_dir(name) / "session.json"


def _messages_path(name: str) -> Path:
    return _session_dir(name) / "messages.json"


def _ensure_unique_name(name: str) -> None:
    if _session_dir(name).exists():
        raise SessionNameExistsError(name)


def _load_session(name: str) -> SessionMeta:
    data = read_json(_session_meta_path(name))
    if data is None:
        raise SessionNotFoundError(name)
    return SessionMeta.model_validate(data)


def _write_session(meta: SessionMeta) -> None:
    write_json(_session_meta_path(meta.name), meta.model_dump(mode="json"))


def _to_response(meta: SessionMeta) -> SessionResponse:
    return SessionResponse(
        name=meta.name,
        mode=meta.mode,
        user_description=meta.user_description,
        scan_depth=meta.scan_depth,
        mem_length=meta.mem_length,
        created_at=meta.created_at,
        updated_at=meta.updated_at,
        main_api_config_id=meta.main_api_config_id,
        scheduler_api_config_id=meta.scheduler_api_config_id,
        preset_id=meta.preset_id,
        version=meta.version,
    )


def create_session(payload: SessionCreate) -> SessionResponse:
    _sessions_dir().mkdir(parents=True, exist_ok=True)
    _ensure_unique_name(payload.name)
    now = datetime.utcnow()
    meta = SessionMeta(
        name=payload.name,
        mode=payload.mode,
        user_description=payload.user_description,
        scan_depth=payload.scan_depth,
        mem_length=payload.mem_length,
        created_at=now,
        updated_at=now,
        main_api_config_id=payload.main_api_config_id,
        scheduler_api_config_id=payload.scheduler_api_config_id,
        preset_id=payload.preset_id,
        version=1,
    )

    session_dir = _session_dir(payload.name)
    session_dir.mkdir(parents=True, exist_ok=True)
    _write_session(meta)
    write_json(_messages_path(payload.name), [])
    rst_data = session_dir / "rst_data"
    (rst_data / "characters").mkdir(parents=True, exist_ok=True)
    (rst_data / ".index").mkdir(parents=True, exist_ok=True)
    return _to_response(meta)


def list_sessions() -> list[SessionSummary]:
    sessions_dir = _sessions_dir()
    sessions_dir.mkdir(parents=True, exist_ok=True)
    summaries: list[SessionSummary] = []
    for path in sessions_dir.iterdir():
        if not path.is_dir():
            continue
        data = read_json(path / "session.json")
        if not isinstance(data, dict):
            continue
        try:
            meta = SessionMeta.model_validate(data)
        except Exception:
            continue
        summaries.append(
            SessionSummary(name=meta.name, mode=meta.mode, updated_at=meta.updated_at)
        )
    return sorted(
        summaries, key=lambda item: (item.updated_at, item.name.lower()), reverse=True
    )


def get_session(name: str) -> SessionResponse:
    return _to_response(_load_session(name))


def update_session(name: str, payload: SessionUpdate) -> SessionResponse:
    meta = _load_session(name)
    updates = payload.model_dump(exclude_unset=True)
    updates["updated_at"] = datetime.utcnow()
    updates["version"] = meta.version + 1
    updated = meta.model_copy(update=updates)
    _write_session(updated)
    return _to_response(updated)


def delete_session(name: str) -> None:
    session_dir = _session_dir(name)
    if not session_dir.exists():
        raise SessionNotFoundError(name)
    shutil.rmtree(session_dir)


def rename_session(name: str, payload: SessionRename) -> SessionResponse:
    if name == payload.new_name:
        return get_session(name)
    meta = _load_session(name)
    _ensure_unique_name(payload.new_name)
    old_dir = _session_dir(name)
    new_dir = _session_dir(payload.new_name)
    old_dir.rename(new_dir)
    updated = meta.model_copy(
        update={
            "name": payload.new_name,
            "updated_at": datetime.utcnow(),
            "version": meta.version + 1,
        }
    )
    write_json(new_dir / "session.json", updated.model_dump(mode="json"))
    return _to_response(updated)


__all__ = [
    "SessionNotFoundError",
    "SessionNameExistsError",
    "create_session",
    "list_sessions",
    "get_session",
    "update_session",
    "delete_session",
    "rename_session",
]

