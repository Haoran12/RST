from __future__ import annotations

import re
from dataclasses import dataclass

_DATE_SEP_RE = re.compile(
    r"(?<!\d)([-+]?\d{1,6})\s*[-/.]\s*(\d{1,3})\s*[-/.]\s*(\d{1,3})(?!\d)"
)
_DATE_ZH_RE = re.compile(
    r"(?<!\d)([-+]?\d{1,6})\s*年\s*(\d{1,3})\s*月\s*(\d{1,3})\s*日?(?!\d)"
)

_SCENE_HINTS = (
    "scene",
    "场景",
    "当前日期",
    "当前时间",
    "日期",
    "时间",
    "today",
    "date",
)


@dataclass(frozen=True)
class FantasyDate:
    year: int
    month: int
    day: int


def _from_groups(year_raw: str, month_raw: str, day_raw: str) -> FantasyDate | None:
    try:
        year = int(year_raw)
        month = int(month_raw)
        day = int(day_raw)
    except ValueError:
        return None

    if month <= 0 or day <= 0:
        return None
    return FantasyDate(year=year, month=month, day=day)


def _find_dates(text: str) -> list[FantasyDate]:
    dates: list[tuple[int, FantasyDate]] = []
    for pattern in (_DATE_ZH_RE, _DATE_SEP_RE):
        for match in pattern.finditer(text):
            parsed = _from_groups(match.group(1), match.group(2), match.group(3))
            if parsed is None:
                continue
            dates.append((match.start(), parsed))
    dates.sort(key=lambda item: item[0])
    return [item[1] for item in dates]


def parse_fantasy_date(text: str) -> FantasyDate | None:
    """Parse the first numeric Y-M-D date from free text."""
    if not text:
        return None
    found = _find_dates(text)
    if not found:
        return None
    return found[0]


def extract_scene_date(text: str) -> FantasyDate | None:
    """
    Extract scene current date from conversation context.
    Priority:
    1) Last date on lines containing scene/date hints.
    2) Last date found in the full text.
    """
    if not text:
        return None

    hinted_last: FantasyDate | None = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        lowered = line.lower()
        if not any(hint in lowered for hint in _SCENE_HINTS):
            continue
        matches = _find_dates(line)
        if matches:
            hinted_last = matches[-1]

    if hinted_last is not None:
        return hinted_last

    all_matches = _find_dates(text)
    if not all_matches:
        return None
    return all_matches[-1]


def compute_age_at(birth: FantasyDate, scene: FantasyDate) -> int:
    age = scene.year - birth.year
    if (scene.month, scene.day) < (birth.month, birth.day):
        age -= 1
    return age


def is_birthday_today(birth: FantasyDate, scene: FantasyDate) -> bool:
    return (birth.month, birth.day) == (scene.month, scene.day)


def format_fantasy_date(value: FantasyDate) -> str:
    return f"{value.year:04d}-{value.month:02d}-{value.day:02d}"


__all__ = [
    "FantasyDate",
    "compute_age_at",
    "extract_scene_date",
    "format_fantasy_date",
    "is_birthday_today",
    "parse_fantasy_date",
]
