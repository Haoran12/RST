from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from app.models.preset import (
    PresetCreate,
    PresetRename,
    PresetResponse,
    PresetSummary,
    PresetUpdate,
)
from app.services.preset_service import (
    PresetInUseError,
    PresetNameExistsError,
    PresetNotFoundError,
    PresetValidationError,
    create_preset,
    delete_preset,
    get_preset,
    list_presets,
    rename_preset,
    update_preset,
)

router = APIRouter()


@router.post("", status_code=status.HTTP_201_CREATED, response_model=PresetResponse)
def create_preset_route(payload: PresetCreate):
    try:
        return create_preset(payload)
    except PresetNameExistsError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.get("", response_model=list[PresetSummary])
def list_presets_route():
    return list_presets()


@router.get("/{preset_id}", response_model=PresetResponse)
def get_preset_route(preset_id: str):
    try:
        return get_preset(preset_id)
    except PresetNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.put("/{preset_id}", response_model=PresetResponse)
def update_preset_route(preset_id: str, payload: PresetUpdate):
    try:
        return update_preset(preset_id, payload)
    except PresetNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PresetValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.delete("/{preset_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_preset_route(preset_id: str):
    try:
        delete_preset(preset_id)
    except PresetNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PresetInUseError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    return None


@router.patch("/{preset_id}/rename", response_model=PresetResponse)
def rename_preset_route(preset_id: str, payload: PresetRename):
    try:
        return rename_preset(preset_id, payload)
    except PresetNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PresetNameExistsError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc

