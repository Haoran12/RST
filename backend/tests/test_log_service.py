from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from app.config import settings
from app.models.log import LogEntry
from app.services.log_service import LogService


def _entry(
    *,
    log_id: str,
    model: str,
    source: str,
    status: str,
    request_time: str,
) -> LogEntry:
    return LogEntry(
        id=log_id,
        chat_name="SessionA",
        request_source=source,
        provider="openai",
        model=model,
        status=status,
        request_time=request_time,
        response_time=request_time,
        duration_ms=123,
        raw_request={"k": "v"},
        raw_response={"ok": True},
    )


def test_log_service_persists_reads_and_cleans(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    logs_dir = tmp_path / "logs"
    monkeypatch.setattr(settings, "rst_logs_dir", str(logs_dir))
    service = LogService(max_logs=None)

    service.add_log(
        _entry(
            log_id="log-main",
            model="gpt-4o-mini",
            source="main",
            status="success",
            request_time="2026-03-05T10:20:30.123456+00:00",
        )
    )
    service.add_log(
        _entry(
            log_id="log-scheduler",
            model="claude/sonnet",
            source="scheduler",
            status="error",
            request_time="2026-03-05T10:20:31.123456+00:00",
        )
    )

    files = sorted(logs_dir.glob("*.json"))
    assert len(files) == 2
    names = [path.name for path in files]
    assert any("gpt-4o-miniMain LLMsuccess" in name for name in names)
    assert any("claudesonnetSche LLMerror" in name for name in names)

    logs = service.get_logs()
    assert [item.id for item in logs] == ["log-scheduler", "log-main"]
    assert service.get_log_by_id("log-main") is not None
    assert service.get_log_by_id("missing") is None

    expired_file = logs_dir / "expired.json"
    expired_file.write_text("{}", encoding="utf-8")
    old_ts = (datetime.now(timezone.utc) - timedelta(days=8)).timestamp()
    os.utime(expired_file, (old_ts, old_ts))

    removed = service.cleanup_expired_logs(retention_days=7)
    assert removed == 1
    assert not expired_file.exists()
