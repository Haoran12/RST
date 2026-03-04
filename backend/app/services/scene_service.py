from __future__ import annotations

import json
import re

from app.models.lore import SceneState
from app.models.session import Message
from app.services.rst_runtime_service import rst_runtime_service
from app.services.session_service import get_session_dir
from app.storage.lore_store import LoreStore

SCENE_TAG_RE = re.compile(r"<scene>\s*(.*?)\s*</scene>", re.IGNORECASE | re.DOTALL)
SCENE_FIELD_RE = re.compile(
    r"^(time|location|characters)\s*[:：]\s*(.+)$",
    re.IGNORECASE | re.MULTILINE,
)
SCENE_BLOCK_RE = re.compile(r"<scene>\s*.*?\s*</scene>", re.IGNORECASE | re.DOTALL)
SCENE_CHARACTER_SPLIT_RE = re.compile(r"[，,、;；]")


def _normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip())


class SceneService:
    """Parse, persist, compare and render scene tracking state."""

    def parse_scene_tag(self, text: str) -> SceneState | None:
        matches = list(SCENE_TAG_RE.finditer(text))
        if not matches:
            return None

        # Scene tag is expected near the end of assistant output.
        # When multiple tags exist, prefer the last one as the latest state.
        raw = matches[-1].group(1).strip()
        scene = SceneState(raw_tag=raw)
        for field_match in SCENE_FIELD_RE.finditer(raw):
            key = field_match.group(1).strip().lower()
            value = field_match.group(2).strip()
            if key == "time":
                scene.current_time = value
            elif key == "location":
                scene.current_location = value
            elif key == "characters":
                scene.characters = [
                    name.strip()
                    for name in SCENE_CHARACTER_SPLIT_RE.split(value)
                    if name.strip()
                ]
        return scene

    def normalize_scene(self, scene: SceneState) -> str:
        payload = {
            "time": _normalize_text(scene.current_time),
            "location": _normalize_text(scene.current_location),
            "characters": [_normalize_text(name).lower() for name in scene.characters if name.strip()],
        }
        return json.dumps(payload, ensure_ascii=False, sort_keys=True)

    def scenes_equal(self, a: SceneState | None, b: SceneState | None) -> bool:
        if a is None and b is None:
            return True
        if a is None or b is None:
            return False
        return self.normalize_scene(a) == self.normalize_scene(b)

    def strip_scene_tag(self, text: str) -> str:
        stripped = SCENE_BLOCK_RE.sub("", text)
        stripped = re.sub(r"\n{3,}", "\n\n", stripped)
        return stripped.strip()

    def deduplicate_history(self, messages: list[Message]) -> list[Message]:
        if len(messages) <= 1:
            return list(messages)

        deduplicated = list(messages)
        assistant_indexes = [index for index, msg in enumerate(messages) if msg.role == "assistant"]
        if len(assistant_indexes) <= 1:
            return deduplicated

        last_assistant_index = assistant_indexes[-1]
        next_scene: SceneState | None = None

        for index in reversed(assistant_indexes):
            current = deduplicated[index]
            parsed = self.parse_scene_tag(current.content)
            if index == last_assistant_index:
                next_scene = parsed
                continue

            if parsed is not None and self.scenes_equal(parsed, next_scene):
                stripped = self.strip_scene_tag(current.content)
                if stripped != current.content:
                    deduplicated[index] = current.model_copy(update={"content": stripped})
            else:
                next_scene = parsed

        return deduplicated

    def merge_scene_state(self, previous: SceneState, parsed: SceneState) -> SceneState:
        return SceneState(
            current_time=parsed.current_time or previous.current_time,
            current_location=parsed.current_location or previous.current_location,
            characters=parsed.characters if parsed.characters else previous.characters,
            raw_tag=parsed.raw_tag or previous.raw_tag,
            updated_at=parsed.updated_at or previous.updated_at,
        )

    def load_scene_state(self, session_name: str) -> SceneState:
        runtime_state = rst_runtime_service.get_session_state(session_name).get("scene_state")
        if isinstance(runtime_state, dict):
            try:
                return SceneState.model_validate(runtime_state)
            except Exception:
                pass

        store = LoreStore(get_session_dir(session_name))
        scene = store.load_scene_state()
        rst_runtime_service.update_session_state(
            session_name,
            scene_state=scene.model_dump(mode="json"),
        )
        return scene

    def save_scene_state(self, session_name: str, scene: SceneState) -> None:
        store = LoreStore(get_session_dir(session_name))
        store.save_scene_state(scene)
        rst_runtime_service.update_session_state(
            session_name,
            scene_state=scene.model_dump(mode="json"),
        )

    def render_scene_prompt(self, scene: SceneState | None) -> str:
        if scene is None or not scene.current_time.strip():
            return (
                "## 场景标记指令\n"
                "在你的每次回复最开头，先附加以下格式的场景标记，再开始正文：\n"
                "<scene>\n"
                "time: [当前故事内的绝对时间，如：灵纪1042年3月15日 黄昏]\n"
                "location: [当前场景地点全称]\n"
                "characters: [当前在场人物名，逗号分隔]\n"
                "</scene>\n\n"
                "要求：\n"
                "- time 必须写绝对时间，禁止写\"三天后\"\"翌日\"等相对表述\n"
                "- 如果本轮回复中时间、地点、在场人物均未发生任何变化，则不需要输出 <scene> 标记\n"
                "- <scene> 标记不属于故事正文，仅用于系统追踪"
            )

        characters = ", ".join(scene.characters)
        return (
            "## 当前场景\n"
            f"time: {scene.current_time}\n"
            f"location: {scene.current_location}\n"
            f"characters: {characters}\n\n"
            "## 场景标记指令\n"
            "在你的每次回复最开头，如果时间、地点或在场人物发生了变化，"
            "先附加以下格式的场景标记，再开始正文：\n"
            "<scene>\n"
            "time: [更新后的绝对时间]\n"
            "location: [更新后的地点全称]\n"
            "characters: [更新后的在场人物名，逗号分隔]\n"
            "</scene>\n\n"
            "如果本轮回复中场景完全没有变化，则不需要输出 <scene> 标记。"
        )


scene_service = SceneService()


__all__ = ["SceneService", "scene_service"]
