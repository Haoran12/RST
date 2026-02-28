from __future__ import annotations

from time import perf_counter

from fastapi import APIRouter, HTTPException, Query, status

from app.models.lore import (
    ActiveFormUpdate,
    CharacterCreate,
    CharacterData,
    CharacterForm,
    CharacterListResponse,
    CharacterMemory,
    CharacterUpdate,
    ConsolidateResult,
    FormCreate,
    FormUpdate,
    LoreBatchUpdate,
    LoreCategory,
    LoreEntry,
    LoreEntryCreate,
    LoreEntryListResponse,
    LoreEntryUpdate,
    MemoryCreate,
    MemoryListResponse,
    MemoryUpdate,
    ScheduleResult,
    ScheduleStatus,
    SchedulerPromptTemplate,
    SchedulerTemplateUpdate,
    SyncResult,
    SyncStatus,
)
from app.providers.base import ProviderError
from app.services.api_config_service import ApiConfigNotFoundError
from app.services.lore_scheduler import lore_scheduler
from app.services.lore_service import (
    CharacterNotFoundError,
    FormNotFoundError,
    LoreNotFoundError,
    LoreValidationError,
    MemoryNotFoundError,
    lore_service,
)
from app.services.lore_updater import lore_updater
from app.services.rst_runtime_service import rst_runtime_service
from app.services.session_service import (
    SessionNotFoundError,
    get_session_dir,
    get_session_storage,
)
from app.storage.message_store import MessageStore
from app.storage.encryption import EncryptionError

router = APIRouter()


def _resolve_category(value: str | None) -> LoreCategory | None:
    if value is None:
        return None
    try:
        return LoreCategory(value)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="Invalid lore category") from exc


def _scheduler_config_id(session_name: str) -> str:
    session = get_session_storage(session_name)
    if not session.scheduler_api_config_id:
        raise HTTPException(status_code=400, detail="scheduler_api_config_id is required in RST mode")
    return session.scheduler_api_config_id


def _recent_messages(session_name: str, scan_depth: int):
    store = MessageStore(get_session_dir(session_name))
    if scan_depth == 0:
        return []
    if scan_depth < 0:
        return store.load_all()
    return store.load_recent(scan_depth)


@router.get(
    "/sessions/{session_name}/lores/entries",
    response_model=LoreEntryListResponse,
)
def list_entries_route(
    session_name: str,
    category: str | None = Query(default=None),
):
    try:
        resolved = _resolve_category(category)
        entries = lore_service.list_entries(session_name, resolved)
        return LoreEntryListResponse(entries=entries, total=len(entries))
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except LoreValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/sessions/{session_name}/lores/entries",
    status_code=status.HTTP_201_CREATED,
    response_model=LoreEntry,
)
def create_entry_route(session_name: str, payload: LoreEntryCreate):
    try:
        return lore_service.create_entry(session_name, payload)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except LoreValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.put(
    "/sessions/{session_name}/lores/entries/batch",
    response_model=LoreEntryListResponse,
)
def batch_update_entries_route(session_name: str, payload: LoreBatchUpdate):
    try:
        entries = lore_service.batch_update(session_name, payload)
        return LoreEntryListResponse(entries=entries, total=len(entries))
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get(
    "/sessions/{session_name}/lores/entries/{entry_id}",
    response_model=LoreEntry | CharacterData,
)
def get_entry_route(session_name: str, entry_id: str):
    try:
        return lore_service.get_entry(session_name, entry_id)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except LoreNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.put(
    "/sessions/{session_name}/lores/entries/{entry_id}",
    response_model=LoreEntry,
)
def update_entry_route(session_name: str, entry_id: str, payload: LoreEntryUpdate):
    try:
        return lore_service.update_entry(session_name, entry_id, payload)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except LoreNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete(
    "/sessions/{session_name}/lores/entries/{entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_entry_route(session_name: str, entry_id: str):
    try:
        lore_service.delete_entry(session_name, entry_id)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except LoreNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return None


@router.get(
    "/sessions/{session_name}/lores/characters",
    response_model=CharacterListResponse,
)
def list_characters_route(session_name: str):
    try:
        characters = lore_service.list_characters(session_name)
        return CharacterListResponse(characters=characters, total=len(characters))
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post(
    "/sessions/{session_name}/lores/characters",
    status_code=status.HTTP_201_CREATED,
    response_model=CharacterData,
)
def create_character_route(session_name: str, payload: CharacterCreate):
    try:
        return lore_service.create_character(session_name, payload)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get(
    "/sessions/{session_name}/lores/characters/{character_id}",
    response_model=CharacterData,
)
def get_character_route(session_name: str, character_id: str):
    try:
        return lore_service.get_character(session_name, character_id)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except CharacterNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.put(
    "/sessions/{session_name}/lores/characters/{character_id}",
    response_model=CharacterData,
)
def update_character_route(session_name: str, character_id: str, payload: CharacterUpdate):
    try:
        return lore_service.update_character(session_name, character_id, payload)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except CharacterNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete(
    "/sessions/{session_name}/lores/characters/{character_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_character_route(session_name: str, character_id: str):
    try:
        lore_service.delete_character(session_name, character_id)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except CharacterNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return None


@router.post(
    "/sessions/{session_name}/lores/characters/{character_id}/forms",
    status_code=status.HTTP_201_CREATED,
    response_model=CharacterForm,
)
def add_form_route(session_name: str, character_id: str, payload: FormCreate):
    try:
        return lore_service.add_form(session_name, character_id, payload)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except CharacterNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.put(
    "/sessions/{session_name}/lores/characters/{character_id}/forms/{form_id}",
    response_model=CharacterForm,
)
def update_form_route(
    session_name: str,
    character_id: str,
    form_id: str,
    payload: FormUpdate,
):
    try:
        return lore_service.update_form(session_name, character_id, form_id, payload)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except CharacterNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except FormNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete(
    "/sessions/{session_name}/lores/characters/{character_id}/forms/{form_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_form_route(session_name: str, character_id: str, form_id: str):
    try:
        lore_service.delete_form(session_name, character_id, form_id)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except CharacterNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except FormNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except LoreValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return None


@router.put(
    "/sessions/{session_name}/lores/characters/{character_id}/active-form",
    response_model=CharacterData,
)
def set_active_form_route(
    session_name: str,
    character_id: str,
    payload: ActiveFormUpdate,
):
    try:
        return lore_service.set_active_form(session_name, character_id, payload)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except CharacterNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except FormNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get(
    "/sessions/{session_name}/lores/characters/{character_id}/memories",
    response_model=MemoryListResponse,
)
def list_memories_route(session_name: str, character_id: str):
    try:
        memories = lore_service.list_memories(session_name, character_id)
        return MemoryListResponse(memories=memories, total=len(memories))
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except CharacterNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post(
    "/sessions/{session_name}/lores/characters/{character_id}/memories",
    status_code=status.HTTP_201_CREATED,
    response_model=CharacterMemory,
)
def add_memory_route(session_name: str, character_id: str, payload: MemoryCreate):
    try:
        return lore_service.add_memory(session_name, character_id, payload)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except CharacterNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.put(
    "/sessions/{session_name}/lores/characters/{character_id}/memories/{memory_id}",
    response_model=CharacterMemory,
)
def update_memory_route(
    session_name: str,
    character_id: str,
    memory_id: str,
    payload: MemoryUpdate,
):
    try:
        return lore_service.update_memory(session_name, character_id, memory_id, payload)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except MemoryNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete(
    "/sessions/{session_name}/lores/characters/{character_id}/memories/{memory_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_memory_route(session_name: str, character_id: str, memory_id: str):
    try:
        lore_service.delete_memory(session_name, character_id, memory_id)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except MemoryNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return None


@router.post(
    "/sessions/{session_name}/lores/characters/{character_id}/memories/consolidate",
    response_model=ConsolidateResult,
)
async def consolidate_memories_route(session_name: str, character_id: str):
    try:
        scheduler_id = _scheduler_config_id(session_name)
        return await lore_updater.consolidate_memories(
            session_name=session_name,
            character_id=character_id,
            scheduler_api_config_id=scheduler_id,
        )
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ApiConfigNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except EncryptionError as exc:
        raise HTTPException(status_code=500, detail="Encryption error") from exc
    except ProviderError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.post(
    "/sessions/{session_name}/lores/schedule",
    response_model=ScheduleResult,
)
async def trigger_schedule_route(session_name: str):
    try:
        session = get_session_storage(session_name)
        scheduler_id = _scheduler_config_id(session_name)
        messages = _recent_messages(session_name, session.scan_depth)

        latest_user = next((msg for msg in reversed(messages) if msg.visible and msg.role == "user"), None)
        user_input = latest_user.content if latest_user is not None else "continue"

        started_at = perf_counter()
        rst = await lore_scheduler.full_schedule(
            session_name=session_name,
            messages=messages,
            scan_depth=session.scan_depth,
            user_input=user_input,
            scheduler_api_config_id=scheduler_id,
        )
        duration_ms = int((perf_counter() - started_at) * 1000)
        state = rst_runtime_service.get_session_state(session_name)
        return ScheduleResult(
            injection_block=rst,
            matched_entry_ids=list(state.get("last_matched_entry_ids", [])),
            duration_ms=duration_ms,
        )
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ApiConfigNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except EncryptionError as exc:
        raise HTTPException(status_code=500, detail="Encryption error") from exc
    except ProviderError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get(
    "/sessions/{session_name}/lores/schedule/status",
    response_model=ScheduleStatus,
)
def get_schedule_status_route(session_name: str):
    try:
        get_session_storage(session_name)
        return lore_scheduler.get_status(session_name)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post(
    "/sessions/{session_name}/lores/sync",
    response_model=SyncResult,
)
async def trigger_sync_route(session_name: str):
    try:
        session = get_session_storage(session_name)
        scheduler_id = _scheduler_config_id(session_name)
        messages = _recent_messages(session_name, session.scan_depth)
        return await lore_updater.sync_from_conversation(
            session_name=session_name,
            messages=messages,
            scan_depth=session.scan_depth,
            scheduler_api_config_id=scheduler_id,
        )
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ApiConfigNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except EncryptionError as exc:
        raise HTTPException(status_code=500, detail="Encryption error") from exc
    except ProviderError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get(
    "/sessions/{session_name}/lores/sync/status",
    response_model=SyncStatus,
)
def get_sync_status_route(session_name: str):
    try:
        return lore_updater.get_status(session_name)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get(
    "/sessions/{session_name}/lores/scheduler-template",
    response_model=SchedulerPromptTemplate,
)
def get_scheduler_template_route(session_name: str):
    try:
        return lore_service.get_scheduler_template(session_name)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.put(
    "/sessions/{session_name}/lores/scheduler-template",
    response_model=SchedulerPromptTemplate,
)
def update_scheduler_template_route(
    session_name: str,
    payload: SchedulerTemplateUpdate,
):
    try:
        return lore_service.update_scheduler_template(session_name, payload)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
