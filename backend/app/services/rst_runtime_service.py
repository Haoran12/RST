from __future__ import annotations

import asyncio
from collections.abc import Awaitable
from typing import Any


class RstRuntimeService:
    """Track per-session runtime tasks/state and support forced shutdown."""

    def __init__(self) -> None:
        self._session_tasks: dict[str, set[asyncio.Task[Any]]] = {}
        self._session_state: dict[str, dict[str, Any]] = {}

    def register_task(self, session_name: str, task: asyncio.Task[Any]) -> None:
        tasks = self._session_tasks.setdefault(session_name, set())
        tasks.add(task)

        def _on_done(done_task: asyncio.Task[Any]) -> None:
            self.unregister_task(session_name, done_task)

        task.add_done_callback(_on_done)

    def unregister_task(self, session_name: str, task: asyncio.Task[Any]) -> None:
        tasks = self._session_tasks.get(session_name)
        if not tasks:
            return
        tasks.discard(task)
        if not tasks:
            self._session_tasks.pop(session_name, None)

    def update_session_state(self, session_name: str, **updates: Any) -> None:
        if not updates:
            return
        state = self._session_state.setdefault(session_name, {})
        state.update(updates)

    def get_session_state(self, session_name: str) -> dict[str, Any]:
        state = self._session_state.get(session_name)
        if not state:
            return {}
        return dict(state)

    def clear_session_state(self, session_name: str) -> None:
        self._session_state.pop(session_name, None)

    async def shutdown_session(self, session_name: str) -> None:
        tasks = list(self._session_tasks.get(session_name, set()))
        for task in tasks:
            if not task.done():
                task.cancel()
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        self._session_tasks.pop(session_name, None)
        self.clear_session_state(session_name)

    async def shutdown_all(self) -> None:
        names = set(self._session_tasks.keys()) | set(self._session_state.keys())
        for name in names:
            await self.shutdown_session(name)

    def has_running_tasks(self, session_name: str) -> bool:
        tasks = self._session_tasks.get(session_name, set())
        return any(not task.done() for task in tasks)

    async def await_task(self, awaitable: Awaitable[Any]) -> Any:
        return await awaitable


rst_runtime_service = RstRuntimeService()


__all__ = ["rst_runtime_service", "RstRuntimeService"]
