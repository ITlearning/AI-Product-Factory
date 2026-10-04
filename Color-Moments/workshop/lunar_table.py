"""한국 음력 표 — 앱(Shared/Word/lunar-days.json)과 공방(cond.py)이 같은 표를 읽는다."""
import json
import sys
from datetime import date, timedelta

from korean_lunar_calendar import KoreanLunarCalendar


def lunar_of(d):
    cal = KoreanLunarCalendar()
    cal.setSolarDate(d.year, d.month, d.day)
    iso = cal.LunarIsoFormat()
    # 윤달('... Intercalation')은 평달과 같은 월-일이어도 맞지 않는 날이다.
    return None if "Intercalation" in iso else iso[5:10]


def build(keys, start=2000, end=2060):
    days, d = {}, date(start, 1, 1)
    while d <= date(end, 12, 31):
        k = lunar_of(d)
        got = [k] if k in keys else []
        # 12-last = 섣달의 마지막 날 — 29일이나 30일로 끝나므로 다음 날이 음력 1월 1일인지로 판단한다.
        if "12-last" in keys and k and k.startswith("12-") and lunar_of(d + timedelta(days=1)) == "01-01":
            got.append("12-last")
        if got:
            days[d.isoformat()] = got
        d += timedelta(days=1)
    return days


if __name__ == "__main__":
    words = json.load(open(sys.argv[1]))["words"]
    keys = {k for w in words for k in w.get("lunar", [])}
    json.dump({"version": 1, "days": build(keys)}, open(sys.argv[2], "w"), ensure_ascii=False, separators=(",", ":"))
