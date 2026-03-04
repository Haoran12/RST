from __future__ import annotations

from app.services.lore_date import (
    FantasyDate,
    compute_age_at,
    extract_scene_date,
    is_birthday_today,
    parse_fantasy_date,
)


def test_parse_fantasy_date_supports_non_gregorian_numeric_date() -> None:
    parsed = parse_fantasy_date("神历 1200年15月20日")
    assert parsed == FantasyDate(year=1200, month=15, day=20)


def test_extract_scene_date_prefers_scene_hint_lines() -> None:
    text = "\n".join(
        [
            "assistant: 回忆发生于 1200-01-01",
            "system scene: 当前日期 1218-15-20",
            "user: 准备行动",
        ]
    )
    parsed = extract_scene_date(text)
    assert parsed == FantasyDate(year=1218, month=15, day=20)


def test_compute_age_and_birthday_for_fantasy_dates() -> None:
    birth = FantasyDate(year=1200, month=15, day=20)
    scene = FantasyDate(year=1218, month=15, day=20)
    assert compute_age_at(birth, scene) == 18
    assert is_birthday_today(birth, scene) is True
