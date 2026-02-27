from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from app.models.api_config import (
    ApiConfigCreate,
    ApiConfigResponse,
    ApiConfigSummary,
    ApiConfigUpdate,
    ModelListResponse,
    ProviderType,
)
from app.providers.base import ProviderError
from app.providers.registry import get_provider
from app.services.api_config_service import (
    ApiConfigInUseError,
    ApiConfigNameExistsError,
    ApiConfigNotFoundError,
    EncryptionError,
    create_api_config,
    delete_api_config,
    get_api_config,
    get_api_config_storage,
    list_api_configs,
    update_api_config,
)
from app.storage.encryption import decrypt_api_key

router = APIRouter()


@router.post("", status_code=status.HTTP_201_CREATED, response_model=ApiConfigResponse)
def create_config(payload: ApiConfigCreate):
    try:
        return create_api_config(payload)
    except ApiConfigNameExistsError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except EncryptionError as exc:
        raise HTTPException(status_code=500, detail="Encryption error") from exc


@router.get("", response_model=list[ApiConfigSummary])
def list_configs():
    return list_api_configs()


@router.get("/{config_id}", response_model=ApiConfigResponse)
def get_config(config_id: str):
    try:
        return get_api_config(config_id)
    except ApiConfigNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except EncryptionError as exc:
        raise HTTPException(status_code=500, detail="Encryption error") from exc


@router.put("/{config_id}", response_model=ApiConfigResponse)
def update_config(config_id: str, payload: ApiConfigUpdate):
    try:
        return update_api_config(config_id, payload)
    except ApiConfigNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ApiConfigNameExistsError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except EncryptionError as exc:
        raise HTTPException(status_code=500, detail="Encryption error") from exc


@router.delete("/{config_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_config(config_id: str):
    try:
        delete_api_config(config_id)
    except ApiConfigInUseError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except ApiConfigNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return None


@router.get("/{config_id}/models", response_model=ModelListResponse)
async def list_models(config_id: str) -> ModelListResponse:
    try:
        config = get_api_config_storage(config_id)
        api_key = decrypt_api_key(config.encrypted_key)
        provider = get_provider(config.provider)
    except ApiConfigNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except EncryptionError as exc:
        raise HTTPException(status_code=500, detail="Encryption error") from exc

    try:
        models = await provider.list_models(config.base_url, api_key)
        response = ModelListResponse(models=models)
        if config.provider == ProviderType.ANTHROPIC:
            response.error = (
                "Anthropic does not provide a public model list; showing common models."
            )
        return response
    except ProviderError as exc:
        return ModelListResponse(models=[], error=str(exc))
