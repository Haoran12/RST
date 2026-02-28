from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from app.models.session import (
    SessionCreate,
    SessionRename,
    SessionResponse,
    SessionSummary,
    SessionUpdate,
)
from app.services.session_service import (
    SessionNameExistsError,
    SessionNotFoundError,
    SessionValidationError,
    create_session,
    delete_session,
    get_session,
    list_sessions,
    rename_session,
    update_session,
)
from app.services.rst_runtime_service import rst_runtime_service
from app.services.lore_scheduler import lore_scheduler

router = APIRouter()


@router.post("", status_code=status.HTTP_201_CREATED, response_model=SessionResponse)
def create_session_route(payload: SessionCreate):
    try:
        return create_session(payload)
    except SessionNameExistsError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except SessionValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("", response_model=list[SessionSummary])
def list_sessions_route():
    return list_sessions()


@router.get("/{name}", response_model=SessionResponse)
def get_session_route(name: str):
    try:
        return get_session(name)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.put("/{name}", response_model=SessionResponse)
async def update_session_route(name: str, payload: SessionUpdate):
    try:
        updated = update_session(name, payload)
        if updated.is_closed:
            await rst_runtime_service.shutdown_session(name)
            lore_scheduler.release_session(name)
        return updated
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except SessionValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.delete("/{name}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session_route(name: str):
    try:
        await rst_runtime_service.shutdown_session(name)
        lore_scheduler.release_session(name)
        delete_session(name)
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return None


@router.patch("/{name}/rename", response_model=SessionResponse)
def rename_session_route(name: str, payload: SessionRename):
    try:
        renamed = rename_session(name, payload)
        if renamed.name != name:
            lore_scheduler.release_session(name)
            rst_runtime_service.clear_session_state(name)
        return renamed
    except SessionNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except SessionNameExistsError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc

