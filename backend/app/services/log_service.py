from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path
import re
from typing import Optional

from pydantic import ValidationError

from app.config import settings
from app.models.log import LogEntry
from app.storage.file_io import read_json, write_json
from app.time_utils import APP_TIMEZONE, now_local, now_local_iso, to_local_tz


class LogService:
    def __init__(self, max_logs: int | None = None):
        self.max_logs = max_logs

    def _logs_dir(self) -> Path:
        path = settings.logs_path
        path.mkdir(parents=True, exist_ok=True)
        return path

    def _sanitize_filename_part(self, value: str, fallback: str) -> str:
        cleaned = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "", value).strip()
        return cleaned or fallback

    def _source_label(self, request_source: str | None) -> str:
        if request_source == "scheduler":
            return "Sche LLM"
        return "Main LLM"

    def _parse_iso_datetime(self, value: str | None) -> datetime | None:
        if not value:
            return None
        normalized = value.replace("Z", "+00:00")
        try:
            parsed = datetime.fromisoformat(normalized)
        except ValueError:
            return None
        return to_local_tz(parsed)

    def _normalize_iso_string(self, value: str | None) -> str | None:
        parsed = self._parse_iso_datetime(value)
        if parsed is None:
            return value
        return parsed.isoformat()

    def _normalize_log_entry(self, log_entry: LogEntry) -> LogEntry:
        request_time = self._normalize_iso_string(log_entry.request_time) or now_local_iso()
        response_time = self._normalize_iso_string(log_entry.response_time)
        return log_entry.model_copy(
            update={
                "request_time": request_time,
                "response_time": response_time,
            }
        )

    def _request_time_for_filename(self, log_entry: LogEntry) -> datetime:
        parsed = self._parse_iso_datetime(log_entry.request_time)
        return parsed or now_local()

    def _build_filename(self, log_entry: LogEntry) -> str:
        request_time = self._request_time_for_filename(log_entry)
        date_part = request_time.strftime("%Y%m%d")
        time_part = request_time.strftime("%H%M%S%f")
        model_part = self._sanitize_filename_part(log_entry.model, "unknown-model")
        source_part = self._source_label(log_entry.request_source)
        status_part = self._sanitize_filename_part(log_entry.status, "unknown")
        return f"{date_part}{time_part}{model_part}{source_part}{status_part}.json"

    def _next_available_path(self, filename: str) -> Path:
        logs_dir = self._logs_dir()
        base_path = logs_dir / filename
        if not base_path.exists():
            return base_path

        stem = base_path.stem
        suffix = base_path.suffix
        index = 1
        while True:
            candidate = logs_dir / f"{stem}_{index}{suffix}"
            if not candidate.exists():
                return candidate
            index += 1

    def _load_log_file(self, path: Path) -> LogEntry | None:
        payload = read_json(path)
        if not isinstance(payload, dict):
            return None
        try:
            return self._normalize_log_entry(LogEntry.model_validate(payload))
        except ValidationError:
            return None

    def _iter_log_paths(self) -> list[Path]:
        return [path for path in self._logs_dir().glob("*.json") if path.is_file()]

    def _sort_logs_desc(self, logs: list[LogEntry]) -> list[LogEntry]:
        def _sort_key(log_entry: LogEntry) -> datetime:
            parsed = self._parse_iso_datetime(log_entry.request_time)
            return parsed or datetime.min.replace(tzinfo=APP_TIMEZONE)

        return sorted(logs, key=_sort_key, reverse=True)

    def add_log(self, log_entry: LogEntry) -> None:
        normalized_entry = self._normalize_log_entry(log_entry)
        path = self._next_available_path(self._build_filename(normalized_entry))
        write_json(path, normalized_entry.model_dump(mode="json"))

    def get_logs(self) -> list[LogEntry]:
        entries: list[LogEntry] = []
        for path in self._iter_log_paths():
            entry = self._load_log_file(path)
            if entry is not None:
                entries.append(entry)
        sorted_entries = self._sort_logs_desc(entries)
        if self.max_logs is None:
            return sorted_entries
        return sorted_entries[: self.max_logs]

    def get_log_by_id(self, log_id: str) -> Optional[LogEntry]:
        for path in self._iter_log_paths():
            entry = self._load_log_file(path)
            if entry is not None and entry.id == log_id:
                return entry
        return None

    def cleanup_expired_logs(self, retention_days: int = 7) -> int:
        if retention_days < 0:
            retention_days = 0
        threshold = now_local() - timedelta(days=retention_days)
        removed = 0
        for path in self._iter_log_paths():
            try:
                modified_time = datetime.fromtimestamp(path.stat().st_mtime, tz=APP_TIMEZONE)
            except OSError:
                continue
            if modified_time >= threshold:
                continue
            try:
                path.unlink()
            except OSError:
                continue
            removed += 1
        return removed


log_service = LogService()
