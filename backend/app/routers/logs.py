from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.models.log import LogCleanupResult, LogEntry
from app.services.log_service import log_service

router = APIRouter()


@router.get("/logs", response_model=list[LogEntry])
def list_logs() -> list[LogEntry]:
    return log_service.get_logs()


@router.delete("/logs/expired", response_model=LogCleanupResult)
def delete_expired_logs(retention_days: int = 7) -> LogCleanupResult:
    removed = log_service.cleanup_expired_logs(retention_days=retention_days)
    return LogCleanupResult(removed=removed)


@router.get("/logs/{log_id}", response_model=LogEntry)
def get_log(log_id: str) -> LogEntry:
    log = log_service.get_log_by_id(log_id)
    if log is None:
        raise HTTPException(status_code=404, detail="Log not found")
    return log
