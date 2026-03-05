from __future__ import annotations

import importlib

import pytest


@pytest.mark.parametrize("configured_tz", ["Asia/Shanghai", "Invalid/Timezone"])
def test_time_utils_init_does_not_crash_without_tzdata(
    monkeypatch: pytest.MonkeyPatch,
    configured_tz: str,
) -> None:
    monkeypatch.setenv("RST_LOCAL_TIMEZONE", configured_tz)

    import app.time_utils as time_utils

    reloaded = importlib.reload(time_utils)
    now = reloaded.now_local()

    assert now.tzinfo is not None
    assert reloaded.now_local_iso()
