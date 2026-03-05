from __future__ import annotations

from app.models.lore import SceneState
from app.models.session import Message
from app.time_utils import now_local

def _assistant(message_id: str, content: str) -> Message:
    return Message(
        id=message_id,
        role="assistant",
        content=content,
        timestamp=now_local(),
        visible=True,
    )


def _user(message_id: str, content: str) -> Message:
    return Message(
        id=message_id,
        role="user",
        content=content,
        timestamp=now_local(),
        visible=True,
    )


def test_parse_scene_tag_prefers_last_tag_and_supports_cn_colon() -> None:
    service = SceneService()
    text = (
        "姝ｆ枃 A\n"
        "<scene>\n"
        "time: 鐏电邯1042骞?鏈?5鏃?榛勬槒\n"
        "location: 浠婂涵路浜戦殣灞盶n"
        "characters: 鑻嶈, 灏忔邯\n"
        "</scene>\n"
        "姝ｆ枃 B\n"
        "<scene>\n"
        "time锛氱伒绾?042骞?鏈?8鏃?鍗堝悗\n"
        "location锛氭辰婧惵锋疆姹愬煄路娓彛\n"
        "characters锛氭煶鐠冦€佸皬婧紱鑰佽埞闀? 闃垮洓\n"
        "</scene>"
    )

    parsed = service.parse_scene_tag(text)
    assert parsed is not None
    assert parsed.current_time == "鐏电邯1042骞?鏈?8鏃?鍗堝悗"
    assert parsed.current_location == "娉芥簮路娼睈鍩幝锋腐鍙?
    assert parsed.characters == ["鏌崇拑", "灏忔邯", "鑰佽埞闀?, "闃垮洓"]
    assert "location锛氭辰婧惵锋疆姹愬煄路娓彛" in parsed.raw_tag

    assert service.parse_scene_tag("娌℃湁鍦烘櫙鏍囩") is None


def test_deduplicate_history_strips_older_scene_when_next_assistant_scene_is_same() -> None:
    service = SceneService()
    scene_same = "<scene>\ntime: T1\nlocation: L1\ncharacters: A, B\n</scene>"
    scene_changed = "<scene>\ntime: T2\nlocation: L2\ncharacters: A, B, C\n</scene>"

    messages = [
def _assistant("a1", f"鏁呬簨A\n{scene_same}"),
        _user("u1", "缁х画"),
def _assistant("a2", f"鏁呬簨B\n{scene_same}"),
        _user("u2", "鍘绘柊鍦扮偣"),
def _assistant("a3", f"鏁呬簨C\n{scene_changed}"),
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
        current_time="鐏电邯1042骞?鏈?5鏃?榛勬槒",
        current_location="浠婂涵路浜戦殣灞?,
        characters=["鑻嶈", "灏忔邯"],
        raw_tag="time: ...",
        updated_at="2026-03-04T20:00:00+08:00",
    )
    parsed = SceneState(
        current_time="",
        current_location="娉芥簮路娼睈鍩?,
        characters=[],
        raw_tag="location: 娉芥簮路娼睈鍩?,
        updated_at="",
    )

    merged = service.merge_scene_state(previous, parsed)
    assert merged.current_time == previous.current_time
    assert merged.current_location == "娉芥簮路娼睈鍩?
    assert merged.characters == previous.characters
    assert merged.raw_tag == "location: 娉芥簮路娼睈鍩?
    assert merged.updated_at == previous.updated_at


def test_render_scene_prompt_for_initial_and_followup_turns() -> None:
    service = SceneService()

    initial_prompt = service.render_scene_prompt(None)
    assert "鍦烘櫙鏍囪鎸囦护" in initial_prompt
    assert "<scene>" in initial_prompt
    assert "time 蹇呴』鍐欑粷瀵规椂闂? in initial_prompt
    assert "鏈€寮€澶? in initial_prompt

    followup_prompt = service.render_scene_prompt(
        SceneState(
            current_time="鐏电邯1042骞?鏈?5鏃?榛勬槒",
            current_location="浠婂涵路浜戦殣灞?,
            characters=["鑻嶈", "灏忔邯"],
        )
    )
    assert "## 褰撳墠鍦烘櫙" in followup_prompt
    assert "time: 鐏电邯1042骞?鏈?5鏃?榛勬槒" in followup_prompt
    assert "location: 浠婂涵路浜戦殣灞? in followup_prompt
    assert "characters: 鑻嶈, 灏忔邯" in followup_prompt
    assert "鏈€寮€澶? in followup_prompt









