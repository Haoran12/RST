from __future__ import annotations

from typing import Any

from pydantic import BaseModel


class LogEntry(BaseModel):
    id: str
    chat_name: str
    model: str
    request_time: str
    response_time: str | None = None
    raw_request: Any
    raw_response: Any
