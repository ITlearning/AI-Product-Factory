import cond
import lunar_table


def test_leap_month_is_not_a_normal_day():
    days = lunar_table.build({"06-01"}, 2025, 2025)
    assert "2025-06-25" in days            # 음력 6월 1일
    assert "2025-07-25" not in days        # 윤6월 1일


def test_last_day_of_the_year():
    days = lunar_table.build({"12-last", "12-29"}, 2026, 2026)
    assert days["2026-02-16"] == ["12-29", "12-last"]   # 2026 설날 = 2-17, 섣달이 29일로 끝남


def test_context_reads_the_table(tmp_path, monkeypatch):
    monkeypatch.setattr(cond, "LUNAR", {"2026-02-16": ["12-29", "12-last"]})
    x = cond.Context({"local": "2026-02-16 20:00", "labels": []}, None)
    assert cond.ok({"lunar": ["12-last"]}, x)
    assert not cond.ok({"lunar": ["01-01"]}, x)


def test_dates_past_the_library_range_have_no_key():
    from datetime import date
    assert lunar_table.lunar_of(date(2055, 9, 1)) is None
    assert lunar_table.lunar_of(date(2050, 12, 31)) == "11-18"
    assert lunar_table.build({"08-24"}, 2051, 2055) == {}
