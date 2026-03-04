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
from app.models.lore import (
    LoreCategory,
    LoreFile,
    LoreIndex,
    SceneStateFile,
    SchedulerPromptTemplate,
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


class SessionValidationError(RuntimeError):
    pass


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
        is_closed=meta.is_closed,
        user_description=meta.user_description,
        scan_depth=meta.scan_depth,
        mem_length=meta.mem_length,
        lore_sync_interval=meta.lore_sync_interval,
        created_at=meta.created_at,
        updated_at=meta.updated_at,
        main_api_config_id=meta.main_api_config_id,
        scheduler_api_config_id=meta.scheduler_api_config_id,
        preset_id=meta.preset_id,
        version=meta.version,
    )


def _validate_lore_sync_interval(mem_length: int, lore_sync_interval: int) -> None:
    upper = 5 if mem_length < 0 else min(5, mem_length)
    upper = max(1, upper)
    if lore_sync_interval > upper:
        raise SessionValidationError(
            f"lore_sync_interval must be between 1 and {upper} for current mem_length"
        )


def create_session(payload: SessionCreate) -> SessionResponse:
    _sessions_dir().mkdir(parents=True, exist_ok=True)
    _ensure_unique_name(payload.name)
    _validate_lore_sync_interval(payload.mem_length, payload.lore_sync_interval)
    now = datetime.utcnow()
    meta = SessionMeta(
        name=payload.name,
        mode=payload.mode,
        is_closed=payload.is_closed,
        user_description=payload.user_description,
        scan_depth=payload.scan_depth,
        mem_length=payload.mem_length,
        lore_sync_interval=payload.lore_sync_interval,
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
    default_world = rst_data / "default"
    default_world.mkdir(parents=True, exist_ok=True)

    for category in (
        LoreCategory.WORLD_BASE,
        LoreCategory.SOCIETY,
        LoreCategory.PLACE,
        LoreCategory.FACTION,
        LoreCategory.SKILLS,
        LoreCategory.OTHERS,
        LoreCategory.PLOT,
    ):
        lore_file = LoreFile(world_id="default", category=category, entries=[])
        write_json(default_world / f"{category.value}.json", lore_file.model_dump(mode="json"))

    empty_index = LoreIndex(items=[], updated_at=now)
    write_json(rst_data / ".index" / "index.json", empty_index.model_dump(mode="json"))

    empty_scene_state = SceneStateFile()
    write_json(rst_data / "scene_state.json", empty_scene_state.model_dump(mode="json"))

    default_template = SchedulerPromptTemplate()
    write_json(rst_data / "scheduler_template.json", default_template.model_dump(mode="json"))
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
            SessionSummary(
                name=meta.name,
                mode=meta.mode,
                is_closed=meta.is_closed,
                updated_at=meta.updated_at,
            )
        )
    return sorted(
        summaries, key=lambda item: (item.updated_at, item.name.lower()), reverse=True
    )


def get_session(name: str) -> SessionResponse:
    return _to_response(_load_session(name))


def get_session_storage(name: str) -> SessionMeta:
    return _load_session(name)


def get_session_dir(name: str) -> Path:
    return _session_dir(name)


def update_session(name: str, payload: SessionUpdate) -> SessionResponse:
    meta = _load_session(name)
    updates = payload.model_dump(exclude_unset=True)
    if updates.get("is_closed") is None:
        updates.pop("is_closed", None)
    if updates.get("scan_depth") is None:
        updates.pop("scan_depth", None)
    if updates.get("mem_length") is None:
        updates.pop("mem_length", None)
    if updates.get("lore_sync_interval") is None:
        updates.pop("lore_sync_interval", None)

    next_mem_length = updates.get("mem_length", meta.mem_length)
    next_sync_interval = updates.get("lore_sync_interval", meta.lore_sync_interval)
    _validate_lore_sync_interval(next_mem_length, next_sync_interval)

    updates["updated_at"] = datetime.utcnow()
    updates["version"] = meta.version + 1
    updated = meta.model_copy(update=updates)
    _write_session(updated)
    return _to_response(updated)


def touch_session(name: str) -> None:
    meta = _load_session(name)
    updated = meta.model_copy(update={"updated_at": datetime.utcnow()})
    _write_session(updated)


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
    "SessionValidationError",
    "create_session",
    "list_sessions",
    "get_session",
    "get_session_storage",
    "get_session_dir",
    "update_session",
    "touch_session",
    "delete_session",
    "rename_session",
]

