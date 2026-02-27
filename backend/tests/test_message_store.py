from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from app.models.session import Message
from app.storage.message_store import MessageStore, PAGE_SIZE


def _make_message(message_id: str, content: str) -> Message:
    return Message(
        id=message_id,
        role="user",
        content=content,
        # Use timezone-aware UTC timestamps to avoid deprecation warnings.
        timestamp=datetime.now(timezone.utc),
    )


def test_append_within_single_page(tmp_path: Path) -> None:
    store = MessageStore(tmp_path)
    store.append(_make_message("m1", "hello"))

    assert (tmp_path / "messages.json").exists()
    assert not (tmp_path / "messages_2.json").exists()


def test_append_creates_next_page(tmp_path: Path) -> None:
    store = MessageStore(tmp_path)
    for idx in range(PAGE_SIZE + 1):
        store.append(_make_message(f"m{idx}", f"msg {idx}"))

    assert (tmp_path / "messages.json").exists()
    assert (tmp_path / "messages_2.json").exists()


def test_load_recent_across_pages(tmp_path: Path) -> None:
    store = MessageStore(tmp_path)
    for idx in range(PAGE_SIZE + 5):
        store.append(_make_message(f"m{idx}", f"msg {idx}"))

    recent = store.load_recent(7)
    assert len(recent) == 7
    assert recent[0].id == f"m{PAGE_SIZE - 2}"
    assert recent[-1].id == f"m{PAGE_SIZE + 4}"


def test_load_for_frontend_returns_tail(tmp_path: Path) -> None:
    store = MessageStore(tmp_path)
    for idx in range(PAGE_SIZE + 5):
        store.append(_make_message(f"m{idx}", f"msg {idx}"))

    messages, total = store.load_for_frontend()
    assert total == PAGE_SIZE + 5
    assert len(messages) == 15
    assert messages[0].id == f"m{PAGE_SIZE - 10}"
    assert messages[-1].id == f"m{PAGE_SIZE + 4}"


def test_load_for_frontend_single_page(tmp_path: Path) -> None:
    store = MessageStore(tmp_path)
    for idx in range(3):
        store.append(_make_message(f"m{idx}", f"msg {idx}"))

    messages, total = store.load_for_frontend()
    assert total == 3
    assert len(messages) == 3


def test_update_message_across_pages(tmp_path: Path) -> None:
    store = MessageStore(tmp_path)
    for idx in range(PAGE_SIZE + 2):
        store.append(_make_message(f"m{idx}", f"msg {idx}"))

    updated = store.update_message("m2", content="updated", visible=False)
    assert updated is not None
    assert updated.content == "updated"
    assert updated.visible is False


def test_delete_message_does_not_repage(tmp_path: Path) -> None:
    store = MessageStore(tmp_path)
    for idx in range(PAGE_SIZE + 1):
        store.append(_make_message(f"m{idx}", f"msg {idx}"))

    assert store.delete_message("m1") is True
    page = store.load_page(1)
    assert len(page) == PAGE_SIZE - 1


def test_delete_message_missing_returns_false(tmp_path: Path) -> None:
    store = MessageStore(tmp_path)
    assert store.delete_message("missing") is False
