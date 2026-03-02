from __future__ import annotations

from typing import List, Optional

from app.models.log import LogEntry


class LogService:
    def __init__(self, max_logs: int = 100):
        self.max_logs = max_logs
        self.logs: List[LogEntry] = []

    def add_log(self, log_entry: LogEntry) -> None:
        self.logs.insert(0, log_entry)
        if len(self.logs) > self.max_logs:
            self.logs = self.logs[: self.max_logs]

    def get_logs(self) -> List[LogEntry]:
        return self.logs

    def get_log_by_id(self, log_id: str) -> Optional[LogEntry]:
        for log in self.logs:
            if log.id == log_id:
                return log
        return None


log_service = LogService()
