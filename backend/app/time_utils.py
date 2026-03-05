from __future__ import annotations

import os
from datetime import datetime, timezone, tzinfo
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def _device_local_timezone() -> tzinfo:
    local_tz = datetime.now().astimezone().tzinfo
    if local_tz is None:
        return timezone.utc
    return local_tz


def _resolve_app_timezone() -> tuple[tzinfo, str, bool]:
    configured_timezone = os.getenv("RST_LOCAL_TIMEZONE", "").strip()
    if configured_timezone:
        try:
            return ZoneInfo(configured_timezone), configured_timezone, False
        except ZoneInfoNotFoundError:
            pass

    local_tz = _device_local_timezone()
    return local_tz, str(local_tz), True


APP_TIMEZONE, APP_TIMEZONE_NAME, _USE_SYSTEM_LOCAL_TIME = _resolve_app_timezone()


def now_local() -> datetime:
    if _USE_SYSTEM_LOCAL_TIME:
        return datetime.now().astimezone()
    return datetime.now(APP_TIMEZONE)


def now_local_iso() -> str:
    return now_local().isoformat()


def to_local_tz(value: datetime) -> datetime:
    if _USE_SYSTEM_LOCAL_TIME:
        if value.tzinfo is None:
            return value.astimezone()
        return value.astimezone()
    if value.tzinfo is None:
        return value.replace(tzinfo=APP_TIMEZONE)
    return value.astimezone(APP_TIMEZONE)
