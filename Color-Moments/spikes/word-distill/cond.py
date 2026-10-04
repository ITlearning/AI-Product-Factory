"""새 말의 사실 조건 판정 — 앱 WordPicker.judge 와 같은 규칙(모르는 날씨·기온이면 고르지 않는다).
해 높이·달 나이는 Shared/Word/Celestial.swift 를 옮긴 것. lunar·solar 는 앱에 아직 없는 새 조건."""
import json
import math
import os
from datetime import datetime, timedelta, timezone

from korean_lunar_calendar import KoreanLunarCalendar

LAB = os.path.expanduser("~/mongdol-word-lab")
SEOUL = (37.5665, 126.978)
WEATHER = {"맑음": "clear", "구름 조금": "clear", "흐림": "cloudy", "이슬비": "drizzle", "비": "rain", "눈": "snow",
           "안개": "fog", "바람": "wind", "뇌우": "rain"}


def _fnv(s):
    h = 0xCBF29CE484222325
    for b in s.encode():
        h = ((h ^ b) * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return format(h, "x")[:8]


def places():
    """키 → (UTC 시각, 위도, 경도). survey 의 local 은 맥(한국) 시간으로 적혀 있다."""
    out = {}
    for f in ["survey-eval.jsonl", "survey.jsonl"]:
        for line in open(f"{LAB}/{f}"):
            r = json.loads(line)
            utc = datetime.strptime(r["local"], "%Y-%m-%dT%H:%M").replace(tzinfo=timezone(timedelta(hours=9)))
            for prefix in ["t-", "x-"]:
                out.setdefault(prefix + _fnv(r["id"]), (utc, r["lat"], r["lon"]))
    days = json.load(open(os.path.expanduser("~/Downloads/mongdol-backup-20261001/days.json")))
    for d in days:
        utc = datetime.fromisoformat(d["capturedAt"].replace("Z", "+00:00"))
        p = d.get("place") or {}
        out["m-" + d["id"][:8]] = (utc, p.get("latitude", SEOUL[0]), p.get("longitude", SEOUL[1]))
    return out


def _julian(t):
    return t.timestamp() / 86400 + 2440587.5


def sun_altitude(t, lat, lon):
    rad = math.pi / 180
    n = _julian(t) - 2451545.0
    mean_lon = math.fmod(280.460 + 0.9856474 * n, 360)
    anomaly = math.fmod(357.528 + 0.9856003 * n, 360) * rad
    ecl = (mean_lon + 1.915 * math.sin(anomaly) + 0.020 * math.sin(2 * anomaly)) * rad
    obl = (23.439 - 0.0000004 * n) * rad
    ra = math.atan2(math.cos(obl) * math.sin(ecl), math.cos(ecl))
    dec = math.asin(math.sin(obl) * math.sin(ecl))
    sidereal = math.fmod(18.697374558 + 24.06570982441908 * n, 24)
    ha = (sidereal * 15 + lon) * rad - ra
    return math.asin(math.sin(lat * rad) * math.sin(dec) + math.cos(lat * rad) * math.cos(dec) * math.cos(ha)) / rad


def moon_age(t):
    age = math.fmod(_julian(t) - 2451550.1, 29.530588853)
    return age + 29.530588853 if age < 0 else age


def time_band(h):
    return "dawn" if 4 <= h < 7 else "morning" if 7 <= h < 11 else "noon" if 11 <= h < 15 else \
        "afternoon" if 15 <= h < 17 else "dusk" if 17 <= h < 20 else "night"


def season(m):
    return "spring" if 3 <= m <= 5 else "summer" if 6 <= m <= 8 else "autumn" if 9 <= m <= 11 else "winter"


class Context:
    def __init__(self, row, place):
        local = datetime.strptime(row["local"], "%Y-%m-%d %H:%M")
        self.hour, self.month = local.hour, local.month
        self.band, self.season = time_band(local.hour), season(local.month)
        self.solar = local.strftime("%m-%d")
        cal = KoreanLunarCalendar()
        cal.setSolarDate(local.year, local.month, local.day)
        self.lunar = cal.LunarIsoFormat()[5:10]
        labels = set(row.get("labels") or [])
        self.weather = WEATHER.get(row.get("weather") or "") or (
            "snow" if "snow" in labels else "clear" if "blue_sky" in labels else "cloudy" if "cloudy" in labels else None)
        self.celsius = row.get("celsius")
        utc, lat, lon = place or (local.replace(tzinfo=timezone(timedelta(hours=9))), *SEOUL)
        self.sun = sun_altitude(utc, lat or SEOUL[0], lon or SEOUL[1])
        self.moon = moon_age(utc)


def ok(c, x):
    """True 일 때만 고를 수 있다(앱의 judge == .yes)."""
    if c.get("times") and x.band not in c["times"]:
        return False
    if c.get("hours") and x.hour not in c["hours"]:
        return False
    if c.get("seasons") and x.season not in c["seasons"]:
        return False
    if c.get("months") and x.month not in c["months"]:
        return False
    if "sunMin" in c and x.sun < c["sunMin"]:
        return False
    if "sunMax" in c and x.sun > c["sunMax"]:
        return False
    if "sun" in c.get("needs", []) and (x.sun < 0 or x.weather != "clear"):
        return False
    if c.get("moonAges") and not any(a <= x.moon <= b for a, b in c["moonAges"]):
        return False
    if c.get("lunar") and x.lunar not in c["lunar"]:
        return False
    if c.get("solar") and x.solar not in c["solar"]:
        return False
    if c.get("weathers") and (x.weather is None or x.weather not in c["weathers"]):
        return False
    if c.get("conditions"):
        return False
    if ("minCelsius" in c or "maxCelsius" in c):
        if x.celsius is None:
            return False
        if "minCelsius" in c and x.celsius < c["minCelsius"]:
            return False
        if "maxCelsius" in c and x.celsius > c["maxCelsius"]:
            return False
    return True
