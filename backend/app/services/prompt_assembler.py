from __future__ import annotations

from app.models.preset import Preset, PresetEntry, SYSTEM_ENTRIES
from app.models.session import Message, SessionMeta


class PromptAssembler:
    def build(
        self,
        session: SessionMeta,
        preset: Preset,
        messages: list[Message],
        lores_block: str,
        user_input: str,
    ) -> list[dict]:
        result: list[dict] = []
        history = self._select_history(session, messages)

        for entry in preset.entries:
            if entry.disabled:
                continue
            if entry.name == "chat_history":
                for msg in history:
                    result.append({"role": msg.role, "content": msg.content})
                continue

            content = self._resolve_content(entry, session, lores_block, user_input)
            if content:
                result.append({"role": entry.role, "content": content})
        return result

    def _select_history(self, session: SessionMeta, messages: list[Message]) -> list[Message]:
        visible = [msg for msg in messages if msg.visible]
        if session.mem_length == 0:
            return []
        if session.mem_length < 0:
            return visible
        return visible[-session.mem_length :]

    def _resolve_content(
        self,
        entry: PresetEntry,
        session: SessionMeta,
        lores_block: str,
        user_input: str,
    ) -> str | None:
        if entry.name == "Main_Prompt":
            return entry.content or None
        if entry.name not in SYSTEM_ENTRIES:
            return entry.content or None

        match entry.name:
            case "lores":
                return lores_block or None
            case "user_description":
                return session.user_description or None
            case "user_input":
                return user_input
            case "scene":
                return None
            case _:
                return None
