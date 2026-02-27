from __future__ import annotations

from pathlib import Path

from app.models.session import Message
from app.storage.file_io import read_json, write_json

PAGE_SIZE = 100


class MessageStore:
    """Manage paged message storage for a single session."""

    def __init__(self, session_dir: Path) -> None:
        self.session_dir = session_dir
        self.session_dir.mkdir(parents=True, exist_ok=True)

    def _page_path(self, page: int) -> Path:
        if page <= 1:
            return self.session_dir / "messages.json"
        return self.session_dir / f"messages_{page}.json"

    def _list_pages(self) -> list[int]:
        pages: list[int] = []
        for path in self.session_dir.glob("messages*.json"):
            if path.name == "messages.json":
                pages.append(1)
                continue
            stem = path.stem
            if stem.startswith("messages_"):
                suffix = stem.split("_", 1)[1]
                if suffix.isdigit():
                    pages.append(int(suffix))
        return sorted(set(pages))

    def _load_page_raw(self, page: int) -> list[dict]:
        data = read_json(self._page_path(page))
        if not data or not isinstance(data, list):
            return []
        return data

    def get_total_count(self) -> int:
        pages = self._list_pages()
        if not pages:
            return 0
        latest = max(pages)
        latest_count = len(self._load_page_raw(latest))
        return (latest - 1) * PAGE_SIZE + latest_count

    def get_latest_page_number(self) -> int:
        pages = self._list_pages()
        return max(pages) if pages else 1

    def append(self, message: Message) -> None:
        page = self.get_latest_page_number()
        items = self._load_page_raw(page)
        if len(items) >= PAGE_SIZE:
            page += 1
            items = []
        items.append(message.model_dump(mode="json"))
        write_json(self._page_path(page), items)

    def load_recent(self, count: int) -> list[Message]:
        if count <= 0:
            return []
        pages = self._list_pages()
        if not pages:
            return []
        remaining = count
        results: list[Message] = []
        for page in sorted(pages, reverse=True):
            items = self._load_page_raw(page)
            if not items:
                continue
            if remaining >= len(items):
                slice_items = items
            else:
                slice_items = items[-remaining:]
            results = [Message.model_validate(item) for item in slice_items] + results
            remaining -= len(slice_items)
            if remaining <= 0:
                break
        return results

    def load_page(self, page: int) -> list[Message]:
        return [Message.model_validate(item) for item in self._load_page_raw(page)]

    def load_for_frontend(self) -> tuple[list[Message], int]:
        total = self.get_total_count()
        latest = self.get_latest_page_number()
        messages = self.load_page(latest)
        if latest > 1:
            prev = self.load_page(latest - 1)
            messages = prev[-10:] + messages
        return messages, total

    def update_message(
        self,
        message_id: str,
        content: str | None = None,
        visible: bool | None = None,
    ) -> Message | None:
        pages = self._list_pages()
        for page in pages:
            items = self._load_page_raw(page)
            for idx, raw in enumerate(items):
                msg = Message.model_validate(raw)
                if msg.id != message_id:
                    continue
                updates: dict[str, object] = {}
                if content is not None:
                    updates["content"] = content
                if visible is not None:
                    updates["visible"] = visible
                msg = msg.model_copy(update=updates)
                items[idx] = msg.model_dump(mode="json")
                write_json(self._page_path(page), items)
                return msg
        return None

    def delete_message(self, message_id: str) -> bool:
        pages = self._list_pages()
        for page in pages:
            items = self._load_page_raw(page)
            for idx, raw in enumerate(items):
                msg = Message.model_validate(raw)
                if msg.id != message_id:
                    continue
                del items[idx]
                write_json(self._page_path(page), items)
                return True
        return False
