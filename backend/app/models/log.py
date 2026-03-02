from __future__ import annotations

from typing import Any

from pydantic import BaseModel


class LogEntry(BaseModel):
    id: str
    chat_name: str
    request_source: str = "main"
    provider: str
    model: str
    status: str
    request_time: str
    response_time: str | None = None
    duration_ms: int | None = None
    prompt_tokens: int | None = None
    completion_tokens: int | None = None
    total_tokens: int | None = None
    stop_reason: str | None = None
    raw_request: Any
    raw_response: Any
