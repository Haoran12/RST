from __future__ import annotations

from datetime import datetime

from app.models.lore import SceneState
from app.models.session import Message
from app.services.scene_service import SceneService


def _assistant(message_id: str, content: str) -> Message:
    return Message(
        id=message_id,
        role="assistant",
        content=content,
        timestamp=datetime.utcnow(),
        visible=True,
    )


def _user(message_id: str, content: str) -> Message:
    return Message(
        id=message_id,
        role="user",
        content=content,
        timestamp=datetime.utcnow(),
        visible=True,
    )


def test_parse_scene_tag_prefers_last_tag_and_supports_cn_colon() -> None:
    service = SceneService()
    text = (
        "正文 A\n"
        "<scene>\n"
        "time: 灵纪1042年3月15日 黄昏\n"
        "location: 今庭·云隐山\n"
        "characters: 苍角, 小溪\n"
        "</scene>\n"
        "正文 B\n"
        "<scene>\n"
        "time：灵纪1042年3月18日 午后\n"
        "location：泽源·潮汐城·港口\n"
        "characters：柳璃、小溪；老船长, 阿四\n"
        "</scene>"
    )

    parsed = service.parse_scene_tag(text)
    assert parsed is not None
    assert parsed.current_time == "灵纪1042年3月18日 午后"
    assert parsed.current_location == "泽源·潮汐城·港口"
    assert parsed.characters == ["柳璃", "小溪", "老船长", "阿四"]
    assert "location：泽源·潮汐城·港口" in parsed.raw_tag

    assert service.parse_scene_tag("没有场景标签") is None


def test_deduplicate_history_strips_older_scene_when_next_assistant_scene_is_same() -> None:
    service = SceneService()
    scene_same = "<scene>\ntime: T1\nlocation: L1\ncharacters: A, B\n</scene>"
    scene_changed = "<scene>\ntime: T2\nlocation: L2\ncharacters: A, B, C\n</scene>"

    messages = [
        _assistant("a1", f"故事A\n{scene_same}"),
        _user("u1", "继续"),
        _assistant("a2", f"故事B\n{scene_same}"),
        _user("u2", "去新地点"),
        _assistant("a3", f"故事C\n{scene_changed}"),
    ]

    deduplicated = service.deduplicate_history(messages)

    assert "<scene>" not in deduplicated[0].content
    assert "<scene>" in deduplicated[2].content
    assert "<scene>" in deduplicated[4].content
    # Original messages are not mutated.
    assert "<scene>" in messages[0].content
    assert "<scene>" in messages[2].content


def test_merge_scene_state_fills_missing_fields() -> None:
    service = SceneService()
    previous = SceneState(
        current_time="灵纪1042年3月15日 黄昏",
        current_location="今庭·云隐山",
        characters=["苍角", "小溪"],
        raw_tag="time: ...",
        updated_at="2026-03-04T12:00:00+00:00",
    )
    parsed = SceneState(
        current_time="",
        current_location="泽源·潮汐城",
        characters=[],
        raw_tag="location: 泽源·潮汐城",
        updated_at="",
    )

    merged = service.merge_scene_state(previous, parsed)
    assert merged.current_time == previous.current_time
    assert merged.current_location == "泽源·潮汐城"
    assert merged.characters == previous.characters
    assert merged.raw_tag == "location: 泽源·潮汐城"
    assert merged.updated_at == previous.updated_at


def test_render_scene_prompt_for_initial_and_followup_turns() -> None:
    service = SceneService()

    initial_prompt = service.render_scene_prompt(None)
    assert "场景标记指令" in initial_prompt
    assert "<scene>" in initial_prompt
    assert "time 必须写绝对时间" in initial_prompt
    assert "最开头" in initial_prompt

    followup_prompt = service.render_scene_prompt(
        SceneState(
            current_time="灵纪1042年3月15日 黄昏",
            current_location="今庭·云隐山",
            characters=["苍角", "小溪"],
        )
    )
    assert "## 当前场景" in followup_prompt
    assert "time: 灵纪1042年3月15日 黄昏" in followup_prompt
    assert "location: 今庭·云隐山" in followup_prompt
    assert "characters: 苍角, 小溪" in followup_prompt
    assert "最开头" in followup_prompt
