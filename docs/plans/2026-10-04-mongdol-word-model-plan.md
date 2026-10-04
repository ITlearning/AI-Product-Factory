# 몽돌 단어 학생 모델 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사진을 기기 밖으로 보내지 않고, 기기 안 학생 모델(TinyCLIP 인코더 + 고르기 층)이 넓어진 순우리말 목록(약 1,800개)에서 사진 단어를 고르게 한다.

**Architecture:** `judge`(사실 판정)는 그대로 두고 고르는 방법만 바꾼다. `Shared` 에는 순수 로직과 주입 지점(`WordScorer`)만 두고, Core ML 인코더·고르기 층 파일은 앱 타깃(`ColorMoments/App/`)에만 싣는다. 공방(`Color-Moments/workshop/`, 맥스튜디오)이 목록·음력 표·인코더·고르기 층을 만들고, 앱과 공방은 같은 Swift 전처리 함수와 같은 음력 표를 쓴다.

**Tech Stack:** Swift 5.10 · SwiftUI · Vision · Core ML · Accelerate(vDSP) · XCTest · xcodegen · Python 3.12(torch 2.7.0 고정, coremltools 9.0, transformers, korean-lunar-calendar) · fonttools

**Spec:** [PRD](./2026-10-04-mongdol-word-model-prd.md) · [리뷰 합의](../reviews/2026-10-04-mongdol-word-model/summary.md)

## Global Constraints

- 사진·사진 값(임베딩)은 기기 밖으로 나가지 않는다. 사진 값을 `Moment`·iCloud 에 저장하지 않는다(메모리에만).
- 후보는 `WordPicker.judge == .yes` 인 단어만. 날씨·기온·뇌우가 걸린 단어는 WeatherKit 값이 있을 때만.
- 이미 붙은 단어는 바꾸지 않는다. `rest`(쉬게 하기)는 새로 고를 때만 빠지고 `contradicted` 는 `rest` 를 보지 않는다.
- 기존 170개 id 의 조건을 넓히지 않는다. 새 id 는 지난 모든 버전의 id·`retired` 와 겹치지 않는다. id 는 `^[a-z]+$`.
- iOS 18 최소, 외부 의존성 없음. 모델·`WordModel` 은 앱 타깃에만. 잠금화면 캡처·위젯 확장은 모델을 싣지도 부르지도 않는다.
- 인코더 TinyCLIP-ViT-8M/16(MIT) 기본, Task 7 판정에서 기준 미달이면 39M/16(MIT). MobileCLIP 금지(연구 전용 라이선스).
- 학생 1회: 2초까지 기다리고, 넘거나 실패하면 비우고 다음에 다시, 세 번 실패하면 규칙 단어.
- 뜻풀이(새 단어): 사전 첫 뜻의 첫 문장, 숫자·‘’·「」 없음, 40자 이하. 넘거나 「…의 준말」류는 한 줄로 새로 쓴다.
- 재촉·스트릭·판단 금지. 「AI가 고른 단어」 표시 안 함.
- 코드 주석은 함정만 한 줄(Tabber 규칙). 「왜」는 커밋 메시지에.
- PR ≤ 10파일·400줄(생성 데이터·모델 바이너리는 줄 수에서 뺀다). 브랜치에서 작업, PR 은 `GH_TOKEN=$(gh auth token --user ITlearning)`.
- 검증: `cd Color-Moments && xcodegen generate && xcodebuild -project ColorMoments.xcodeproj -scheme ColorMoments -destination 'id=<iPhone 17 Pro 시뮬 id>' -collect-test-diagnostics never test` (테스트 4분 상한, 시뮬은 켜 둔다).

## Review Focus

1. **iCloud 로 옛 버전과 섞인 사진** — 옛 기기가 모르는 새 id 를 받으면 지우지 않고 그대로 보인다. Task 1 테스트 `testUnknownIDIsNotContradicted`.
2. **음력이 공방과 앱에서 갈리는 날**(윤달, 섣달 29일로 끝나는 해) — 둘이 같은 표를 읽는다. Task 2 `test_leap_month_is_not_a_normal_day`, Task 1 `testLunarWordFollowsTheTable`.
3. **단어 목록이 바뀌었는데 고르기 층이 옛것** — 엉뚱한 단어 대신 규칙으로 간다. Task 6 `testHeadWithDifferentIDsIsRejected`.
4. **모델이 계속 실패하는 사진** — 영원히 빈 칸이 되지 않는다(세 번째에 규칙). Task 4 `testThirdFailureFallsBackToRule`.
5. **그날 조약돌 이름과 같은 단어**(노을·햇살 등) — 그날 사진에는 붙지 않는다. Task 4 `testPebbleNameOfTheDayIsSkipped`.

---

## 분해 (Sprint · PR · DAG)

| Sprint | 목표 (완료 조건) | PR |
|---|---|---|
| S1 판정과 데이터 | `words.json` v6(약 1,800개)·음력 표가 앱에 들어가고 테스트가 초록. 단어 고르기는 아직 규칙. | PR-1, PR-2, PR-3 |
| S2 학생 연결 | 가짜 scorer 로 새 흐름이 테스트되고, 진짜 인코더·고르기 층이 앱에 실려 시뮬에서 단어가 붙는다. | PR-4, PR-5, PR-6, PR-7 |
| S3 판정·출시 | 학생이 47장·처음 보는 30장 모두 기준을 넘고, 문서·고지 정리 후 TestFlight → 출시. | (공방 Task 8) PR-8, (출시 Task 10) |

| PR | Task | 내용 | 의존 |
|---|---|---|---|
| PR-1 | 1 | `WordEntry` 새 필드 + 음력 표 읽기 + `judge` 의 음력·양력 | — |
| PR-2 | 2 | 공방 이전(`spikes/word-distill` → `workshop/`) + 음력 표 생성 + `cond.py` 표 사용 | — |
| PR-3 | 3 | `words.json` v6 생성기 + 데이터 + 명조 다시 굽기 + 목록 테스트 | PR-1, PR-2 |
| PR-4 | 4 | `WordAssist`·`WordAssistant`·`WordChoice` 빼기 | — |
| PR-5 | 5 | `WordScorer`·`WordAttempts`·`WordChooser` + 사진 보기 흐름(↻·조약돌 이름·재시도) | PR-1, PR-4 |
| PR-6 | 6 | 공방: `WordImage` 전처리 + Core ML 인코더 변환 + 사진 값 Swift 추출 + 고르기 층 내보내기 | PR-2 |
| PR-7 | 7 | 앱: `WordModel` + 고르기 층 대조 + 시작 시 데우기 + 확장에서 빼기 | PR-3, PR-5, PR-6, Task 8 의 첫 고르기 층 |
| — | 8 | 공방 운영: v6 로 학생 학습, 8M/39M 판정, 다양성 측정 | PR-3, PR-6 |
| PR-8 | 9 | 문서·고지·설정 문구·디버그 리포트 | PR-7, `fix/mongdol-dictionary-credit` |
| — | 10 | TestFlight·iPhone 13 측정·출시(Tabber) | PR-8 |

```
PR-1 ─┐                 ┌─────────────┐
PR-2 ─┼─> PR-3 ─────────┤             │
      └─> PR-6 ─> Task 8 ─> PR-7 ─> PR-8 ─> Task 10
PR-4 ─> PR-5 ───────────────┘
병렬 가능: {PR-1, PR-2, PR-4} → {PR-3, PR-5, PR-6}
```

## 파일 지도

| 파일 | 책임 | Task |
|---|---|---|
| `Shared/Word/WordList.swift` | `WordEntry` 에 `rest`·`lunar`·`solar`·`group` | 1 |
| `Shared/Word/LunarDays.swift` (새) | `lunar-days.json` 읽기, 날짜 → 음력 키 | 1 |
| `Shared/Word/PhotoContext.swift` | `dateKey`("yyyy-MM-dd")·`solarKey`("MM-dd") | 1 |
| `Shared/Word/WordPicker.swift` | `judge` 음력·양력, `modelCandidates`·`best` | 1, 5 |
| `Shared/Word/lunar-days.json` (생성) | 한국 음력 표 2000~2060 | 2, 3 |
| `Shared/Word/words.json` (생성) | v6 목록 | 3 |
| `workshop/**` | 공방(파이썬·Swift 도구) | 2, 3, 6, 8 |
| `Shared/Word/WordScorer.swift` (새) | 주입 지점 + 2초 상한 | 5 |
| `Shared/Word/WordAttempts.swift` (새) | 사진별 실패 횟수(기기 안 UserDefaults) | 5 |
| `Shared/Word/WordChooser.swift` (새) | 학생/규칙 고르기 결정 — 사진 보기가 부른다 | 5 |
| `Shared/Day/DayPhotoView.swift` | `pickWord`·`reject`·`hasAlternative` 를 `WordChooser` 로 | 5 |
| `Shared/Day/DayStore.swift` | `pebbleName(on:)` | 5 |
| `Shared/Word/WordImage.swift` (새) | 사진 → 224×224 입력(앱·공방 공용) | 6 |
| `ColorMoments/App/WordModel.swift` (새) | 인코더 + 고르기 층, `WordScorer` 꽂기 | 7 |
| `ColorMoments/App/WordEncoder.mlpackage`, `WordHead.json`, `WordHead.bin` (생성) | 모델 | 7 |
| `project.yml` | 확장에서 `words.json`·`lunar-days.json` 빼기 | 7 |

---

## Sprint 1 — 판정과 데이터

### Task 1 (PR-1): `WordEntry` 새 필드와 음력·양력 판정

**Files:**
- Modify: `Color-Moments/Shared/Word/WordList.swift` (WordEntry 필드·CodingKeys·init)
- Create: `Color-Moments/Shared/Word/LunarDays.swift`
- Modify: `Color-Moments/Shared/Word/PhotoContext.swift` (init 에 `dateKey`·`solarKey`)
- Modify: `Color-Moments/Shared/Word/WordPicker.swift` (`judge`)
- Test: `Color-Moments/ColorMomentsTests/WordPickerTests.swift`, Create `Color-Moments/ColorMomentsTests/LunarDaysTests.swift`

**Interfaces:**
- Produces: `WordEntry.rest: Bool`, `.lunar: [String]`, `.solar: [String]`, `.group: String?` · `PhotoContext.dateKey: String`, `.solarKey: String` · `LunarDays.keys(on dateKey: String) -> Set<String>` · `LunarDays.table: [String: [String]]`(테스트가 바꿔 끼운다)

- [ ] **Step 1: 실패하는 테스트**

`ColorMomentsTests/LunarDaysTests.swift`:
```swift
import XCTest
@testable import ColorMoments

final class LunarDaysTests: XCTestCase {
    override func tearDown() { LunarDays.table = LunarDays.load(); super.tearDown() }

    func testKeysComeFromTheTable() {
        LunarDays.table = ["2026-02-16": ["12-29", "12-last"], "2026-02-17": ["01-01"]]
        XCTAssertEqual(LunarDays.keys(on: "2026-02-16"), ["12-29", "12-last"])
        XCTAssertEqual(LunarDays.keys(on: "2026-02-15"), [])
    }
}
```
`WordPickerTests.swift` 끝에 추가:
```swift
    func testSolarWordOnlyOnItsDay() {
        var w = w("kids", subjects: [])
        w.solar = ["05-05"]
        XCTAssertEqual(WordPicker.judge(w, seoul(5, 5, 12)), .yes)
        XCTAssertEqual(WordPicker.judge(w, seoul(5, 6, 12)), .no)
    }

    func testLunarWordFollowsTheTable() {
        defer { LunarDays.table = LunarDays.load() }
        LunarDays.table = ["2026-02-16": ["12-29", "12-last"], "2026-02-17": ["01-01"]]
        var eve = w("eve", subjects: []); eve.lunar = ["12-last"]
        var newYear = w("newyear", subjects: []); newYear.lunar = ["01-01"]
        XCTAssertEqual(WordPicker.judge(eve, seoul(2, 16, 20)), .yes)
        XCTAssertEqual(WordPicker.judge(eve, seoul(2, 15, 20)), .no)
        XCTAssertEqual(WordPicker.judge(newYear, seoul(2, 17, 9)), .yes)
    }

    func testRestIsNotAContradiction() {
        var w = w("plain", subjects: ["food"]); w.rest = true
        XCTAssertFalse(WordPicker.contradicted(PhotoWord(w), context: dusk, in: [w], retired: []))
    }

    func testUnknownIDIsNotContradicted() {
        let future = PhotoWord(wordID: "byeotnwi", word: "볕뉘", meaning: "작은 틈으로 드는 햇볕")
        XCTAssertFalse(WordPicker.contradicted(future, context: dusk, in: [w("sea")], retired: []))
    }

    func testNewFieldsDecode() throws {
        let json = #"{"id":"seolnal","word":"설날","meaning":"음력 정월 초하루","times":[],"weathers":[],"seasons":[],"subjects":[],"rest":true,"lunar":["01-01"],"solar":["05-05"],"group":"때"}"#
        let e = try JSONDecoder().decode(WordEntry.self, from: Data(json.utf8))
        XCTAssertTrue(e.rest); XCTAssertEqual(e.lunar, ["01-01"]); XCTAssertEqual(e.solar, ["05-05"]); XCTAssertEqual(e.group, "때")
        let old = #"{"id":"yunseul","word":"윤슬","meaning":"반짝이는 잔물결","times":[],"weathers":[],"seasons":[],"subjects":["water"]}"#
        let o = try JSONDecoder().decode(WordEntry.self, from: Data(old.utf8))
        XCTAssertFalse(o.rest); XCTAssertEqual(o.lunar, []); XCTAssertNil(o.group)
    }
```

- [ ] **Step 2: 실패 확인**

Run: `cd Color-Moments && xcodegen generate && xcodebuild ... test -only-testing:ColorMomentsTests/LunarDaysTests -only-testing:ColorMomentsTests/WordPickerTests`
Expected: 컴파일 실패(`LunarDays`, `rest`, `lunar`, `solar`, `group`, `dateKey` 없음)

- [ ] **Step 3: 구현**

`WordList.swift` — `WordEntry` 필드 뒤에:
```swift
    public var rest: Bool = false
    public var lunar: [String] = []
    public var solar: [String] = []
    public var group: String?
```
`CodingKeys` 에 `rest, lunar, solar, group` 추가, `init(from:)` 끝에:
```swift
        rest = try c.decodeIfPresent(Bool.self, forKey: .rest) ?? false
        lunar = try c.decodeIfPresent([String].self, forKey: .lunar) ?? []
        solar = try c.decodeIfPresent([String].self, forKey: .solar) ?? []
        group = try c.decodeIfPresent(String.self, forKey: .group)
```
`LunarDays.swift`:
```swift
import Foundation

/// 공방이 korean_lunar_calendar 로 만든 표 — iOS 의 .chinese 는 중국 기준이라 하루 어긋나는 날이 있다.
public enum LunarDays {
    public nonisolated(unsafe) static var table: [String: [String]] = load()

    public static func load() -> [String: [String]] {
        let bundle = Bundle(for: SharedBundleMarker.self)
        guard let url = bundle.url(forResource: "lunar-days", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [:] }
        return file.days
    }

    public static func keys(on dateKey: String) -> Set<String> { Set(table[dateKey] ?? []) }

    struct File: Decodable { let version: Int; let days: [String: [String]] }
}
```
`PhotoContext.swift` — 저장 프로퍼티 추가:
```swift
    public let dateKey: String
    public let solarKey: String
```
`init(date:…)` 에서 `let c = calendar.dateComponents([.hour, .month, .weekday], from: date)` 를 `[.year, .month, .day, .hour, .weekday]` 로 바꾸고:
```swift
        dateKey = String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
        solarKey = String(format: "%02d-%02d", c.month ?? 1, c.day ?? 1)
```
`WordPicker.judge` — `months` 줄 다음에:
```swift
        if !w.solar.isEmpty, !w.solar.contains(ctx.solarKey) { return .no }
        if !w.lunar.isEmpty, LunarDays.keys(on: ctx.dateKey).isDisjoint(with: w.lunar) { return .no }
```
`lunar-days.json` 은 Task 3 에서 넣는다. 그 전까지 `load()` 는 빈 표라 음력 단어는 `.no` — 안전한 쪽이다.

- [ ] **Step 4: 통과 확인** — 같은 명령, Expected: PASS(기존 37개 + 새 6개). 전체 `test` 도 초록.

- [ ] **Step 5: Commit**
```bash
git add Shared/Word/WordList.swift Shared/Word/LunarDays.swift Shared/Word/PhotoContext.swift Shared/Word/WordPicker.swift ColorMomentsTests/WordPickerTests.swift ColorMomentsTests/LunarDaysTests.swift
git commit -m "feat(mongdol): 단어에 쉬게 하기·음력·양력·갈래 — 음력은 한국 음력 표로 판정"
```

### Task 2 (PR-2): 공방 이전과 한국 음력 표

**Files:**
- Move: `Color-Moments/spikes/word-distill/**` → `Color-Moments/workshop/**` (`git mv`)
- Delete: `workshop/prompts.py` 의 `--color`·`--balance` 갈래, `workshop/teacher.py`(170개 시절 선생 — `teacher_expanded.py` 로 대체)
- Create: `workshop/lunar_table.py`, `workshop/test_cond.py`, `workshop/README.md`
- Modify: `workshop/cond.py` (표 사용·윤달)

**Interfaces:**
- Produces: `workshop/lunar_table.py build(keys: set[str], start=2000, end=2060) -> dict[str, list[str]]` · 출력 파일 형식 `{"version": 1, "days": {"2026-02-16": ["12-29", "12-last"]}}` · `cond.Context.lunar_keys: set[str]`
- Consumes: 없음

- [ ] **Step 1: 옮기기**
```bash
cd Color-Moments && git mv spikes/word-distill workshop && git rm workshop/teacher.py
```
`workshop/prompts.py` 에서 `COLOR`·`BALANCE` 분기와 `plain_words.txt` 읽기를 지우고 `--train` 만 남긴다(색채·균형 실험은 회의 기록에 결과가 남아 있다).

- [ ] **Step 2: 실패하는 테스트** `workshop/test_cond.py`
```python
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
```
Run: `cd workshop && ~/.venvs/mongdol-word-lab/bin/python -m pytest test_cond.py -q` → Expected: FAIL(`lunar_table` 없음)

- [ ] **Step 3: 구현** `workshop/lunar_table.py`
```python
"""한국 음력 표 — 앱(Shared/Word/lunar-days.json)과 공방(cond.py)이 같은 표를 읽는다."""
import json
import sys
from datetime import date, timedelta

from korean_lunar_calendar import KoreanLunarCalendar


def lunar_of(d):
    cal = KoreanLunarCalendar()
    cal.setSolarDate(d.year, d.month, d.day)
    iso = cal.LunarIsoFormat()
    return None if "Intercalation" in iso else iso[5:10]


def build(keys, start=2000, end=2060):
    days, d = {}, date(start, 1, 1)
    while d <= date(end, 12, 31):
        k = lunar_of(d)
        got = [k] if k in keys else []
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
```
`workshop/cond.py` — `KoreanLunarCalendar` 계산을 표 읽기로 바꾼다:
```python
LUNAR = json.load(open(os.path.join(os.path.dirname(__file__), "../Shared/Word/lunar-days.json")))["days"] \
    if os.path.exists(os.path.join(os.path.dirname(__file__), "../Shared/Word/lunar-days.json")) else {}
```
`Context.__init__` 의 음력 부분을:
```python
        self.lunar_keys = set(LUNAR.get(local.strftime("%Y-%m-%d"), []))
```
`ok()` 의 음력 줄을:
```python
    if c.get("lunar") and not (set(c["lunar"]) & x.lunar_keys):
        return False
```

- [ ] **Step 4: 통과 확인** — 같은 명령, Expected: 3 passed

- [ ] **Step 5: README** `workshop/README.md` — 환경(`~/.venvs/mongdol-word-lab`, Python 3.12, torch 2.7.0 고정 — coremltools 9.0 이 시험한 최신), 자료 위치(`~/mongdol-word-lab`, 저장소에 사진·사전 원자료를 올리지 않는다), 순서(사진 고르기 `pick_train.py` → 추출 `extract/` → 선생 `teacher_expanded.py [--train]` → 학생 `student.py` → 판정 `judge.py`), 목록 다시 만들기(`build_words.py`, Task 3), 음력 표(`lunar_table.py`).

- [ ] **Step 6: Commit**
```bash
git add -A workshop spikes
git commit -m "chore(mongdol): 단어 공방을 workshop/ 으로 — 한국 음력 표 생성, cond.py 가 같은 표를 읽고 윤달은 맞지 않는 것으로"
```

### Task 3 (PR-3): `words.json` v6

**Files:**
- Create: `workshop/build_words.py`, `workshop/test_build_words.py`
- Create: `Color-Moments/ColorMomentsTests/Fixtures/words-v5.json` (지금 `words.json` 그대로 복사), `ColorMomentsTests/Fixtures/word-ids-history.json`
- Modify(생성): `Shared/Word/words.json`, `Shared/Word/lunar-days.json`, `Shared/Design/Fonts/subset-chars.txt`, `Shared/Design/Fonts/NanumMyeongjo-Subset.ttf`
- Modify: `ColorMomentsTests/WordListTests.swift`, `ColorMomentsTests/FontSubsetTests.swift`(상한), `Shared/Design/Fonts/README.md`(글자 수·크기)

**Interfaces:**
- Consumes: Task 1 의 필드, Task 2 의 `lunar_table.build`
- Produces: `words.json` `version: 6`, 각 새 단어 `{id, word, meaning, times…, rest?, lunar?, solar?, group}`

- [ ] **Step 1: 내용 준비(사람 확인 필요)**

공방에서 두 파일을 만들고 Tabber 확인을 받는다.
1. `~/mongdol-word-lab/meanings-rewrite-v6.json` — 첫 문장이 40자를 넘거나 다른 말을 가리키기만 하는 새 단어(「‘가을바람’의 준말」·「‘금성03’을 이르는 말」 등)를 30자 안쪽 한 줄로. 이미 쓴 158개(`meanings-rewritten.json`)는 그대로 쓰고 나머지만 새로.
2. `~/mongdol-word-lab/old-groups.json` — 기존 170개 단어의 장면 갈래(14개 중 하나).
Claude 가 초안 → Tabber 가 고칠 것만 표시 → 반영.

- [ ] **Step 2: 실패하는 테스트** `workshop/test_build_words.py`
```python
import build_words as b


def test_romanize_is_lowercase_letters():
    assert b.romanize("볕뉘") == "byeotnwi"
    assert b.romanize("해거름") == "haegeoreum"


def test_new_id_avoids_history():
    assert b.new_id("단잠", taken={"danjam"}) == "danjamb"


def test_meaning_cleanup():
    assert b.clean("저녁에 서쪽 하늘에 보이는 ‘금성03’을 이르는 말. 다른 뜻") == "저녁에 서쪽 하늘에 보이는 금성을 이르는 말"
    assert b.points_elsewhere("‘가을바람’의 준말")
```
Run: `cd workshop && ~/.venvs/mongdol-word-lab/bin/python -m pytest test_build_words.py -q` → FAIL

- [ ] **Step 3: 구현** `workshop/build_words.py`
```python
"""words.json v6 — 기존 170개(그대로) + 공방에서 고른 새 단어. id 는 한 번 만들면 고정한다."""
import json
import os
import re
import subprocess
import sys

LAB = os.path.expanduser("~/mongdol-word-lab")
CHO = "g kk n d tt r m b pp s ss  j jj ch k t p h".split(" ")
JUNG = "a ae ya yae eo e yeo ye o wa wae oe yo u wo we wi yu eu ui i".split(" ")
JONG = ["", "k", "k", "ks", "n", "nj", "nh", "t", "l", "lk", "lm", "lb", "ls", "lt", "lp", "lh", "m", "p", "ps",
        "t", "t", "ng", "t", "t", "k", "t", "p", "t"]
FIELDS = ["times", "hours", "sunMin", "sunMax", "needs", "weathers", "conditions", "seasons", "months",
          "minCelsius", "maxCelsius", "moonAges", "lunar", "solar"]


def romanize(word):
    out = []
    for ch in word:
        n = ord(ch) - 0xAC00
        if not 0 <= n < 11172:
            continue
        out.append(CHO[n // 588] + JUNG[(n % 588) // 28] + JONG[n % 28])
    return "".join(out)


def new_id(word, taken):
    base = romanize(word)
    cand, suffix = base, iter("bcdefghijklmnopqrstuvwxyz")
    while cand in taken:
        cand = base + next(suffix)
    return cand


def clean(meaning):
    m = re.sub(r"[‘’]", "", meaning)
    m = re.sub(r"(?<=[가-힣])\d+", "", m)
    m = re.sub(r"「\d+」", "", m)
    return re.split(r"(?<=[다음함임말것])\. ", m.strip().rstrip("."))[0].rstrip(".")


def points_elsewhere(meaning):
    return bool(re.search(r"(준말|본말|높임말|낮춤말|잘못|방언)$", clean(meaning)))


def history_ids(path):
    shas = subprocess.run(["git", "log", "--format=%H", "--", path], capture_output=True, text=True).stdout.split()
    ids = set()
    for h in shas:
        try:
            old = json.loads(subprocess.run(["git", "show", f"{h}:{path}"], capture_output=True, text=True).stdout)
        except json.JSONDecodeError:
            continue
        ids |= {w["id"] for w in old["words"]} | set(old.get("retired", []))
    return ids


def main(words_path):
    cur = json.load(open(words_path))
    taken = history_ids("Color-Moments/Shared/Word/words.json") | {w["id"] for w in cur["words"]} | set(cur.get("retired", []))
    rest_old = {t for l in open("plain_words.txt") if not l.startswith("#") for t in l.split()} | \
        {"어둑발", "짬", "보금자리", "꼬마", "주전부리", "새참", "적바림", "글월", "모꼬지"}
    groups = json.load(open(f"{LAB}/old-groups.json"))
    rewrites = {**json.load(open(f"{LAB}/meanings-rewritten.json")), **json.load(open(f"{LAB}/meanings-rewrite-v6.json"))}
    conds = json.load(open(f"{LAB}/word-conditions.json"))
    vocab = [w for w in json.load(open(f"{LAB}/words-expanded-v5.json")) if w["new"]]
    out = []
    for w in cur["words"]:
        w = dict(w)
        w["group"] = groups[w["word"]]
        if w["word"] in rest_old:
            w["rest"] = True
        out.append(w)
    for v in vocab:
        meaning = rewrites.get(v["word"]) or clean(v.get("meaning_dict", v["meaning"]))
        if len(meaning) > 40 or points_elsewhere(meaning):
            sys.exit(f"새로 쓸 뜻풀이가 빠졌다: {v['word']} — meanings-rewrite-v6.json")
        e = {"id": new_id(v["word"], taken), "word": v["word"], "meaning": meaning,
             "times": [], "weathers": [], "seasons": [], "subjects": [], "group": v["cat"]}
        taken.add(e["id"])
        e.update({k: x for k, x in conds.get(v["word"], {}).items() if k in FIELDS})
        if v.get("rest"):
            e["rest"] = True
        out.append(e)
    cur["version"], cur["words"] = 6, out
    json.dump(cur, open(words_path, "w"), ensure_ascii=False, indent=1)
    print(len(out), "개")


if __name__ == "__main__":
    main(sys.argv[1])
```
- [ ] **Step 4: 공방 테스트 통과** — `pytest test_build_words.py -q` → 3 passed

- [ ] **Step 5: 앱 쪽 실패하는 테스트** `WordListTests.swift`

`testNoWordCollidesWithAPebbleName` 의 마지막 두 줄(`clash` 검사)을 지우고 이름을 `testPebbleNamesAreCollected` 로 바꾼다(같은 날 피하기는 Task 5 가 맡는다). 추가:
```swift
    private func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json")))
    }

    func testOldWordsKeepTheirConditions() throws {
        let old = try JSONDecoder().decode(WordList.self, from: fixture("words-v5"))
        let now = Dictionary(uniqueKeysWithValues: try list().words.map { ($0.id, $0) })
        for o in old.words {
            let n = try XCTUnwrap(now[o.id], "\(o.word) 가 사라졌다 — 이미 붙은 사진에서 지워진다")
            XCTAssertEqual([n.times.map(\.rawValue), n.weathers.map(\.rawValue), n.seasons.map(\.rawValue), n.subjects, n.with,
                            n.conditions, n.needs.map(\.rawValue), n.months.map(String.init), n.hours.map(String.init),
                            n.weekdays.map(String.init)],
                           [o.times.map(\.rawValue), o.weathers.map(\.rawValue), o.seasons.map(\.rawValue), o.subjects, o.with,
                            o.conditions, o.needs.map(\.rawValue), o.months.map(String.init), o.hours.map(String.init),
                            o.weekdays.map(String.init)], "\(o.word) 조건이 바뀌었다 — 넓히면 옛 기기가 지운다")
            XCTAssertEqual([n.sunMin, n.sunMax, n.minCelsius, n.maxCelsius], [o.sunMin, o.sunMax, o.minCelsius, o.maxCelsius], o.word)
            XCTAssertEqual(n.moonAges, o.moonAges, o.word)
        }
    }

    func testNewIDsNeverReuseHistory() throws {
        let history = Set(try JSONDecoder().decode([String].self, from: fixture("word-ids-history")))
        let old = Set(try JSONDecoder().decode(WordList.self, from: fixture("words-v5")).words.map(\.id))
        let reused = try list().words.map(\.id).filter { !old.contains($0) && history.contains($0) }
        XCTAssertTrue(reused.isEmpty, "예전 id·retired 를 다시 썼다: \(reused)")
    }

    func testNewMeaningsAreClean() throws {
        let old = Set(try JSONDecoder().decode(WordList.self, from: fixture("words-v5")).words.map(\.id))
        for w in try list().words where !old.contains(w.id) {
            XCTAssertLessThanOrEqual(w.meaning.count, 40, w.word)
            XCTAssertNil(w.meaning.range(of: "[0-9‘’「」]", options: .regularExpression), "\(w.word): \(w.meaning)")
        }
    }

    func testEveryWordHasAGroup() throws {
        XCTAssertTrue(try list().words.allSatisfy { $0.group != nil })
    }

    func testEveryLunarKeyIsInTheTable() throws {
        let inTable = Set(LunarDays.load().values.flatMap { $0 })
        let missing = try list().words.flatMap(\.lunar).filter { !inTable.contains($0) }
        XCTAssertTrue(missing.isEmpty, "음력 표에 없는 날: \(missing)")
    }
```
`ColorMomentsTests/Fixtures/words-v5.json` = 지금 `Shared/Word/words.json` 복사본. `word-ids-history.json` = `build_words.history_ids(...)` 결과를 정렬한 배열(공방에서 한 번 뽑아 고정).

Run: `xcodebuild … -only-testing:ColorMomentsTests/WordListTests` → FAIL(`group` 없음, 음력 표 없음)

- [ ] **Step 6: 데이터 만들기**
```bash
cd Color-Moments/workshop
cp ../Shared/Word/words.json ../ColorMomentsTests/Fixtures/words-v5.json
~/.venvs/mongdol-word-lab/bin/python -c "import build_words as b, json; json.dump(sorted(b.history_ids('Color-Moments/Shared/Word/words.json')), open('../ColorMomentsTests/Fixtures/word-ids-history.json','w'))"
~/.venvs/mongdol-word-lab/bin/python build_words.py ../Shared/Word/words.json
~/.venvs/mongdol-word-lab/bin/python lunar_table.py ../Shared/Word/words.json ../Shared/Word/lunar-days.json
```
명조 서브셋은 `Shared/Design/Fonts/README.md` 의 「다시 만들 때」 그대로 다시 굽는다(뺀 단어 글자도 지우지 않는다).

- [ ] **Step 7: 글꼴 상한** — `FontSubsetTests.testSubsetStaysSmall` 의 `100_000` 을 실제 크기 + 20% 로 올린다(예: 200KB 면 `240_000`). 메시지에 「v6 단어 약 1,800개로 약 590자」 근거를 적는다. README 의 글자 수·크기 표도 고친다.

- [ ] **Step 8: 통과 확인** — 전체 `test`, Expected: PASS. `testMostWordsHaveSubjects`(>40)·`testEverySubjectIsARealVisionLabel` 는 기존 단어로 계속 통과한다.

- [ ] **Step 9: Commit**
```bash
git add workshop/build_words.py workshop/test_build_words.py Shared/Word/words.json Shared/Word/lunar-days.json Shared/Design/Fonts ColorMomentsTests/WordListTests.swift ColorMomentsTests/FontSubsetTests.swift ColorMomentsTests/Fixtures/words-v5.json ColorMomentsTests/Fixtures/word-ids-history.json
git commit -m "feat(mongdol): 단어 목록 v6 — 표준국어대사전 고유어 약 1,630개, 쉬게 하기 75개, 한국 음력 표, 명조 다시 굽기"
```

## Sprint 2 — 학생 연결

### Task 4 (PR-4): Apple Intelligence 고르기 빼기

**Files:**
- Delete: `ColorMoments/App/WordAssistant.swift`, `Shared/Word/WordChoice.swift`, `ColorMomentsTests/WordChoiceTests.swift`
- Modify: `ColorMoments/App/ColorMomentsApp.swift:23`(`WordAssistant.install()` 줄), `ColorMoments/App/SpikeView.swift:17`(토글), `ColorMoments/App/WordRelabelReport.swift:35,84-90`(모델 줄·verdict), `Shared/Day/DayPhotoView.swift:361-377`(`WordChoice`·`WordAssist` 부분)

- [ ] **Step 1:** 위 파일을 지우고 참조를 뺀다. `pickWord` 는 `WordAssist` 없이 `(first, pool)` 을 돌려준다:
```swift
        guard let first = rule.first ?? pool.first else { return nil }
        return (first, pool)
```
- [ ] **Step 2:** `xcodegen generate` 후 전체 `test` — Expected: PASS(WordChoiceTests 만 사라짐)
- [ ] **Step 3: Commit** — `git commit -m "refactor(mongdol): Apple Intelligence 단어 고르기 빼기 — 학생 모델이 대신한다"`

### Task 5 (PR-5): `WordScorer`·`WordChooser` 와 사진 보기 흐름

**Files:**
- Create: `Shared/Word/WordScorer.swift`, `Shared/Word/WordAttempts.swift`, `Shared/Word/WordChooser.swift`
- Modify: `Shared/Word/WordPicker.swift`(`modelCandidates`·`best`), `Shared/Day/DayPhotoView.swift`(`pickWord`·`reject`·`hasAlternative`), `Shared/Day/DayStore.swift`(`pebbleName(on:)`)
- Test: Create `ColorMomentsTests/WordChooserTests.swift`; `WordPickerTests.swift`

**Interfaces:**
- Consumes: Task 1 `WordEntry.rest/group`, `PhotoContext`
- Produces:
  - `WordScorer.score: (@Sendable (Moment) async throws -> [String: Float])?` · `WordScorer.scores(for: Moment, within: Double = 2) async throws -> [String: Float]`
  - `WordAttempts(defaults: UserDefaults = .standard)`: `failures(_ id: UUID) -> Int`, `fail(_ id: UUID)`, `clear(_ id: UUID)`
  - `WordPicker.modelCandidates(for: PhotoContext, in: [WordEntry], excluding recent: Set<String>, banned: Set<String>, pebbleName: String?) -> [WordEntry]`
  - `WordPicker.best(_ scores: [String: Float], among: [WordEntry], seed: String, notInGroupOf skip: WordEntry?) -> WordEntry?`
  - `WordChooser.Outcome { case word(WordEntry, pool: [WordEntry]); case later }` · `WordChooser.choose(moment: Moment, context: PhotoContext, labels: [String], words: [WordEntry], recent: Set<String>, banned: Set<String>, pebbleName: String?, skip: WordEntry?, attempts: WordAttempts) async -> WordChooser.Outcome?`
  - `DayStore.pebbleName(on dayKey: String) -> String?`

- [ ] **Step 1: 실패하는 테스트** `ColorMomentsTests/WordChooserTests.swift`
```swift
import XCTest
@testable import ColorMoments

final class WordChooserTests: XCTestCase {
    private var attempts: WordAttempts!
    private let ctx = PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600),
                                   calendar: { var c = Calendar(identifier: .gregorian); c.timeZone = .gmt; return c }())
    private let m = Moment(capturedAt: Date(timeIntervalSince1970: 18 * 3600), colorHex: "#888888", fileName: "x.jpg", source: .app)

    private func w(_ id: String, group: String = "물·땅", rest: Bool = false, subjects: [String] = []) -> WordEntry {
        var e = WordEntry(id: id, word: id, meaning: "뜻", times: [], weathers: [], seasons: [], subjects: subjects)
        e.group = group; e.rest = rest; return e
    }

    override func setUp() {
        super.setUp()
        attempts = WordAttempts(defaults: UserDefaults(suiteName: "WordChooserTests")!)
        attempts.clear(m.id)
    }
    override func tearDown() { WordScorer.score = nil; super.tearDown() }

    private func choose(_ words: [WordEntry], recent: Set<String> = [], banned: Set<String> = [], pebble: String? = nil,
                        skip: WordEntry? = nil, labels: [String] = ["ocean"]) async -> WordChooser.Outcome? {
        await WordChooser.choose(moment: m, context: ctx, labels: labels, words: words, recent: recent, banned: banned,
                                 pebbleName: pebble, skip: skip, attempts: attempts)
    }

    private func id(_ o: WordChooser.Outcome?) -> String? { if case .word(let w, _) = o { return w.id }; return nil }

    func testHighestScoreWins() async {
        WordScorer.score = { _ in ["a": 0.2, "b": 0.9] }
        XCTAssertEqual(id(await choose([w("a"), w("b")])), "b")
    }

    func testRestedWordIsNeverPicked() async {
        WordScorer.score = { _ in ["a": 0.2, "b": 0.9] }
        XCTAssertEqual(id(await choose([w("a"), w("b", rest: true)])), "a")
    }

    func testRecentWordIsAvoidedButNotIfItIsTheOnlyOne() async {
        WordScorer.score = { _ in ["a": 0.2, "b": 0.9] }
        XCTAssertEqual(id(await choose([w("a"), w("b")], recent: ["b"])), "a")
        XCTAssertEqual(id(await choose([w("b")], recent: ["b"])), "b")
    }

    func testPebbleNameOfTheDayIsSkipped() async {
        WordScorer.score = { _ in ["노을": 0.9, "윤슬": 0.5] }
        XCTAssertEqual(id(await choose([w("노을"), w("윤슬")], pebble: "노을")), "윤슬")
    }

    func testRetryRejectsTheSameGroup() async {
        WordScorer.score = { _ in ["a": 0.9, "b": 0.8, "c": 0.1] }
        let words = [w("a"), w("b"), w("c", group: "빛·하늘")]
        XCTAssertEqual(id(await choose(words, banned: ["a"], skip: words[0])), "c", "↻ 는 1등과 같은 갈래를 건너뛴다")
    }

    func testNoScorerUsesTheRule() async {
        WordScorer.score = nil
        XCTAssertEqual(id(await choose([w("sea", subjects: ["ocean"]), w("b")])), "sea")
    }

    func testFailureLeavesItForLater() async {
        WordScorer.score = { _ in throw WordScorer.Failure.unavailable }
        if case .later = await choose([w("a")]) {} else { XCTFail("실패하면 이번엔 비워 둔다") }
        XCTAssertEqual(attempts.failures(m.id), 1)
    }

    func testThirdFailureFallsBackToRule() async {
        WordScorer.score = { _ in throw WordScorer.Failure.unavailable }
        attempts.fail(m.id); attempts.fail(m.id); attempts.fail(m.id)
        XCTAssertEqual(id(await choose([w("sea", subjects: ["ocean"])])), "sea")
    }

    func testSlowScorerTimesOut() async {
        WordScorer.score = { _ in try await Task.sleep(for: .seconds(5)); return [:] }
        let start = Date()
        _ = try? await WordScorer.scores(for: m, within: 0.2)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    }

    func testTiesAreBrokenTheSameWayOnEveryDevice() {
        let words = [w("a"), w("b")]
        let x = WordPicker.best(["a": 0.50001, "b": 0.50002], among: words, seed: "s", notInGroupOf: nil)?.id
        let y = WordPicker.best(["a": 0.50001, "b": 0.50002], among: words.reversed(), seed: "s", notInGroupOf: nil)?.id
        XCTAssertEqual(x, y, "fp16 차이로 기기마다 1등이 갈리지 않게 반올림 후 seed 로")
    }
}
```
Run: `xcodebuild … -only-testing:ColorMomentsTests/WordChooserTests` → FAIL(타입 없음)

- [ ] **Step 2: 구현** `Shared/Word/WordScorer.swift`
```swift
import Foundation

/// 앱 타깃이 꽂는다(ColorMoments/App/WordModel.swift). 확장에는 없다 — nil 이면 규칙.
public enum WordScorer {
    public enum Failure: Error { case unavailable, timedOut }

    public nonisolated(unsafe) static var score: (@Sendable (Moment) async throws -> [String: Float])?

    public static func scores(for m: Moment, within seconds: Double = 2) async throws -> [String: Float] {
        guard let score else { throw Failure.unavailable }
        return try await withThrowingTaskGroup(of: [String: Float].self) { group in
            group.addTask { try await score(m) }
            group.addTask { try await Task.sleep(for: .seconds(seconds)); throw Failure.timedOut }
            defer { group.cancelAll() }
            return try await group.next() ?? [:]
        }
    }
}
```
`Shared/Word/WordAttempts.swift`
```swift
import Foundation

/// 사진별 학생 실패 횟수 — 이 기기에만(UserDefaults). 세 번이면 규칙 단어.
public final class WordAttempts: @unchecked Sendable {
    public static let shared = WordAttempts()
    public static let limit = 3
    private let defaults: UserDefaults
    private let key = "wordModelFailures"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private var all: [String: Int] {
        get { defaults.dictionary(forKey: key) as? [String: Int] ?? [:] }
        set { defaults.set(newValue, forKey: key) }
    }
    public func failures(_ id: UUID) -> Int { all[id.uuidString] ?? 0 }
    public func fail(_ id: UUID) { all[id.uuidString, default: 0] += 1 }
    public func clear(_ id: UUID) { all[id.uuidString] = nil }
}
```
`WordPicker.swift` 에 추가:
```swift
    public static func modelCandidates(for ctx: PhotoContext, in words: [WordEntry], excluding recent: Set<String>,
                                       banned: Set<String>, pebbleName: String?) -> [WordEntry] {
        words.filter {
            !$0.rest && !banned.contains($0.id) && !recent.contains($0.id) && $0.word != pebbleName && judge($0, ctx) == .yes
        }
    }

    public static func best(_ scores: [String: Float], among words: [WordEntry], seed: String,
                            notInGroupOf skip: WordEntry?) -> WordEntry? {
        words.filter { scores[$0.id] != nil && (skip == nil || $0.group != skip?.group) }
            .map { (w: $0, s: (scores[$0.id]! * 1000).rounded(), h: fnv1a(seed + ":" + $0.id)) }
            .min { ($0.s, $1.h) > ($1.s, $0.h) }?.w
    }
```
`Shared/Word/WordChooser.swift`
```swift
import Foundation

public enum WordChooser {
    public enum Outcome { case word(WordEntry, pool: [WordEntry]); case later }

    public static func choose(moment m: Moment, context ctx: PhotoContext, labels: [String], words: [WordEntry],
                              recent: Set<String>, banned: Set<String>, pebbleName: String?, skip: WordEntry?,
                              attempts: WordAttempts) async -> Outcome? {
        let seed = m.id.uuidString
        if WordScorer.score != nil, attempts.failures(m.id) < WordAttempts.limit {
            do {
                let scores = try await WordScorer.scores(for: m)
                for avoid in [recent, []] {
                    let pool = WordPicker.modelCandidates(for: ctx, in: words, excluding: avoid, banned: banned, pebbleName: pebbleName)
                    if let w = WordPicker.best(scores, among: pool, seed: seed, notInGroupOf: skip) {
                        attempts.clear(m.id)
                        return .word(w, pool: pool)
                    }
                }
            } catch {
                attempts.fail(m.id)
                return .later
            }
        }
        let rule = WordPicker.candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned)
        let pool = WordPicker.choices(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned)
        return (rule.first ?? pool.first).map { .word($0, pool: pool) }
    }
}
```
`DayStore.swift` 에 추가:
```swift
    public func pebbleName(on dayKey: String) -> String? {
        PebbleNaming.name(for: moments.filter { $0.dayKey == dayKey })?.name
    }
```
`DayPhotoView.swift` — `pickWord` 를 바꾼다:
```swift
    private func pickWord(for m: Moment, labels: [String], banned: Set<String> = [], skip: WordEntry? = nil) async -> (word: WordEntry, pool: [WordEntry])? {
        let words = await BundledWordSource().words()
        let ctx = PhotoContext(current ?? m, labels: labels)
        let recent = store.recentWordIDs(excluding: m.id).union(rejections.avoided)
        switch await WordChooser.choose(moment: current ?? m, context: ctx, labels: labels, words: words, recent: recent,
                                        banned: banned, pebbleName: store.pebbleName(on: m.dayKey), skip: skip,
                                        attempts: .shared) {
        case .word(let w, let pool): return (w, pool)
        case .later, nil: return nil
        }
    }
```
`reject` 에서 `pickWord(for: m, labels: labels, banned: [old.wordID])` 를
```swift
        let oldEntry = BundledWordSource.cached.first { $0.id == old.wordID }
        guard let pick = await pickWord(for: m, labels: labels, banned: [old.wordID], skip: oldEntry) else { return }
```
로, `record` 의 `candidates:` 는 `pick.pool.prefix(20).map(\.id)` 로(수백 개로 커지지 않게). `hasAlternative`:
```swift
    private func hasAlternative(_ m: Moment, _ w: PhotoWord) -> Bool {
        let labels = m.labels ?? []
        let ctx = PhotoContext(m, labels: labels)
        if WordScorer.score != nil {
            let current = BundledWordSource.cached.first { $0.id == w.wordID }
            return WordPicker.modelCandidates(for: ctx, in: BundledWordSource.cached, excluding: [], banned: [w.wordID], pebbleName: nil)
                .contains { $0.group != current?.group }
        }
        return !WordPicker.choices(for: ctx, labels: labels, in: BundledWordSource.cached,
                                   excluding: [], seed: m.id.uuidString, banned: [w.wordID]).isEmpty
    }
```
- [ ] **Step 3: 통과 확인** — `-only-testing:ColorMomentsTests/WordChooserTests` → 10 passed, 전체 `test` 초록
- [ ] **Step 4: Commit** — `git commit -m "feat(mongdol): 단어 고르기 주입 지점(WordScorer) — 학생 1등, 쉬는 말·최근·그날 조약돌 이름 피하기, ↻ 는 다른 갈래, 2초·세 번 실패 규칙"`

### Task 6 (PR-6): 공방 — 같은 전처리, Core ML 인코더, 고르기 층 파일

**Files:**
- Create: `Shared/Word/WordImage.swift` (앱·공방 공용 전처리)
- Create: `workshop/export_encoder.py`, `workshop/export_head.py`, `workshop/embed/main.swift`, `workshop/embed/build.sh`
- Modify: `workshop/student.py` (`--emb coreml-<이름>` 읽기, 쉬는 단어 정답 사진 빼기, 출력 `answers/.student-*`)
- Test: Create `ColorMomentsTests/WordImageTests.swift`, `workshop/test_export_head.py`

**Interfaces:**
- Produces: `WordImage.side = 224` · `WordImage.input(from: CGImage) -> CGImage?`(짧은 변 224 로 줄이고 가운데 224×224) · Core ML 모델 입력 `image`(224×224 RGB, 0~255) 출력 `embedding`(512, L2 정규화) · 고르기 층 `WordHead.json` `{"format":1,"wordsVersion":6,"dim":512,"ids":[…],"mean":[…],"std":[…],"bias":[…]}` + `WordHead.bin`(float16 little-endian, ids×dim 행 우선)

- [ ] **Step 1: 실패하는 테스트** `ColorMomentsTests/WordImageTests.swift`
```swift
import CoreGraphics
import XCTest
@testable import ColorMoments

final class WordImageTests: XCTestCase {
    private func image(_ w: Int, _ h: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    func testLandscapeIsCenterCroppedToSquare() throws {
        let out = try XCTUnwrap(WordImage.input(from: image(800, 600)))
        XCTAssertEqual([out.width, out.height], [224, 224])
    }

    func testPortraitToo() throws {
        let out = try XCTUnwrap(WordImage.input(from: image(600, 900)))
        XCTAssertEqual([out.width, out.height], [224, 224])
    }
}
```
- [ ] **Step 2: 구현** `Shared/Word/WordImage.swift`
```swift
import CoreGraphics

/// 앱과 공방(workshop/embed)이 같은 함수를 컴파일한다 — 전처리가 다르면 학생이 다른 사진을 본다.
public enum WordImage {
    public static let side = 224

    public static func input(from image: CGImage) -> CGImage? {
        let scale = CGFloat(side) / CGFloat(min(image.width, image.height))
        let w = CGFloat(image.width) * scale, h = CGFloat(image.height) * scale
        guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: (CGFloat(side) - w) / 2, y: (CGFloat(side) - h) / 2, width: w, height: h))
        return ctx.makeImage()
    }
}
```
Run `-only-testing:ColorMomentsTests/WordImageTests` → PASS

- [ ] **Step 3: 인코더 변환** `workshop/export_encoder.py`
```python
"""TinyCLIP 이미지 인코더 → Core ML(int8). 정규화·L2 는 모델 안, 리사이즈는 앱 WordImage."""
import sys

import coremltools as ct
import coremltools.optimize.coreml as cto
import torch
from transformers import CLIPModel

REPO = {"8m": "wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M", "39m": "wkcn/TinyCLIP-ViT-39M-16-Text-19M-YFCC15M"}[sys.argv[1]]
MEAN = torch.tensor([0.48145466, 0.4578275, 0.40821073]).view(1, 3, 1, 1)
STD = torch.tensor([0.26862954, 0.26130258, 0.27577711]).view(1, 3, 1, 1)


class Encoder(torch.nn.Module):
    def __init__(self, clip):
        super().__init__()
        self.clip = clip

    def forward(self, x):
        x = (x / 255.0 - MEAN) / STD
        e = self.clip.get_image_features(pixel_values=x)
        return torch.nn.functional.normalize(e, dim=-1)


model = Encoder(CLIPModel.from_pretrained(REPO).eval())
traced = torch.jit.trace(model, torch.rand(1, 3, 224, 224) * 255)
ml = ct.convert(traced, inputs=[ct.ImageType(name="image", shape=(1, 3, 224, 224), color_layout=ct.colorlayout.RGB)],
                outputs=[ct.TensorType(name="embedding")], minimum_deployment_target=ct.target.iOS18)
ml = cto.linear_quantize_weights(ml, cto.OptimizationConfig(global_config=cto.OpLinearQuantizerConfig(mode="linear_symmetric")))
ml.short_description = f"TinyCLIP {sys.argv[1]} image encoder (MIT) — 몽돌 단어"
ml.save(sys.argv[2])
```
Run: `~/.venvs/mongdol-word-lab/bin/python export_encoder.py 8m ~/mongdol-word-lab/WordEncoder-8m.mlpackage` → 파일 ≈ 8MB

- [ ] **Step 4: 사진 값 Swift 추출** `workshop/embed/main.swift` — 앱과 같은 `WordImage` 와 Core ML 모델로 `photos/`·`photos-train/` 의 사진 값을 `~/mongdol-word-lab/emb-coreml-<이름>.json`(`{"keys":[…],"x":[[…]]}`)으로 쓴다.
```swift
import CoreML
import Foundation
import ImageIO

let lab = URL(fileURLWithPath: NSString(string: "~/mongdol-word-lab").expandingTildeInPath)
let (modelPath, name) = (CommandLine.arguments[1], CommandLine.arguments[2])
let config = MLModelConfiguration(); config.computeUnits = .cpuAndNeuralEngine
let model = try MLModel(contentsOf: MLModel.compileModel(at: URL(fileURLWithPath: modelPath)), configuration: config)
var keys: [String] = [], xs: [[Float]] = []
for dir in ["photos", "photos-train"] {
    let files = try FileManager.default.contentsOfDirectory(at: lab.appendingPathComponent(dir), includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "jpg" }.sorted { $0.path < $1.path }
    for f in files {
        guard let src = CGImageSourceCreateWithURL(f as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil), let input = WordImage.input(from: cg) else { continue }
        let out = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["image": try MLFeatureValue(cgImage: input, pixelsWide: 224, pixelsHigh: 224, pixelFormatType: kCVPixelFormatType_32BGRA, options: nil)]))
        let e = out.featureValue(for: "embedding")!.multiArrayValue!
        keys.append(f.deletingPathExtension().lastPathComponent)
        xs.append((0..<e.count).map { Float(truncating: e[$0]) })
    }
}
try JSONSerialization.data(withJSONObject: ["keys": keys, "x": xs]).write(to: lab.appendingPathComponent("emb-coreml-\(name).json"))
print(keys.count, "장")
```
`workshop/embed/build.sh`:
```bash
#!/bin/sh
set -e
here=$(cd "$(dirname "$0")" && pwd)
xcrun swiftc -O -o "$here/.build/embed" "$here/main.swift" "$here/../../Shared/Word/WordImage.swift"
```
`student.py` 의 `--emb` 가 `coreml-` 로 시작하면 `emb-coreml-<이름>.json` 을 읽게 한다(`np.load` 대신 `json.load` → `dict(zip(keys, x))`).

- [ ] **Step 5: 고르기 층 내보내기** — 실패하는 테스트 `workshop/test_export_head.py`
```python
import json

import numpy as np

import export_head


def test_round_trip(tmp_path):
    W = np.random.rand(3, 4).astype(np.float32)
    export_head.write(tmp_path, ids=["a", "b", "c"], W=W, bias=np.zeros(3), mean=np.zeros(4), std=np.ones(4), words_version=6)
    meta = json.load(open(tmp_path / "WordHead.json"))
    back = np.fromfile(tmp_path / "WordHead.bin", dtype="<f2").reshape(3, 4)
    assert meta["ids"] == ["a", "b", "c"] and meta["dim"] == 4 and meta["wordsVersion"] == 6
    assert np.allclose(back, W, atol=1e-3)
```
`workshop/export_head.py`:
```python
"""고르기 층 → WordHead.json(id 목록·mean/std·bias) + WordHead.bin(float16 행렬). id 목록이 words.json 과 다르면 앱이 안 쓴다."""
import json
import os

import numpy as np


def write(out, ids, W, bias, mean, std, words_version):
    os.makedirs(out, exist_ok=True)
    json.dump({"format": 1, "wordsVersion": words_version, "dim": int(W.shape[1]), "ids": list(ids),
               "mean": [float(v) for v in mean], "std": [float(v) for v in std], "bias": [float(v) for v in bias]},
              open(os.path.join(out, "WordHead.json"), "w"), ensure_ascii=False)
    W.astype("<f2").tofile(os.path.join(out, "WordHead.bin"))
```
`student.py` 끝에 `--export <폴더>` 를 받으면 가장 큰 학습(전체 사진)의 `layer.weight`·`layer.bias`·`mean`·`std` 와 `words.json` 순서의 id 로 `export_head.write(...)` 를 부르게 한다. 학생 입력에 들어간 단어만이 아니라 `words.json` 의 모든 id 를 행으로 둔다(학습에서 못 본 단어 행은 bias -1e4 로 — 고르지 않는다).

- [ ] **Step 6: 맥 일치 확인** — PyTorch 사진 값으로 학습한 학생과 Core ML 사진 값으로 학습한 학생의 평가 94장 1등 일치율을 출력하는 한 줄을 `student.py` 에 더하고, ≥ 95% 인지 본다. 미달이면 리사이즈(바이큐빅 vs CoreGraphics)를 의심해 학습 사진 값도 Core ML 쪽으로 통일한다(이미 그렇게 학습한다).

- [ ] **Step 7: Commit** — `git commit -m "feat(mongdol): 공방 — 앱과 같은 전처리(WordImage), TinyCLIP Core ML int8 변환, 고르기 층 파일 내보내기"`

### Task 7 (PR-7): 앱에 학생 모델 싣기

**Files:**
- Create: `ColorMoments/App/WordModel.swift`
- Add(생성): `ColorMoments/App/WordEncoder.mlpackage`, `ColorMoments/App/WordHead.json`, `ColorMoments/App/WordHead.bin` (Task 8 의 결과)
- Modify: `ColorMoments/App/ColorMomentsApp.swift`(시작 시 `WordModel.install()`), `project.yml`(두 확장 `excludes` 에 `"Word/words.json"`, `"Word/lunar-days.json"`)
- Test: Create `ColorMomentsTests/WordModelTests.swift`

**Interfaces:**
- Consumes: `WordScorer.score`, `WordImage.input`, `ShotImage.thumbnail(_:maxPixel:) async -> UIImage?`, `BundledWordSource.cached`
- Produces: `WordModel.install()` · `WordModel.Head.load(json: Data, bin: Data, expected ids: [String]) throws -> Head` · `Head.scores(_ embedding: [Float]) -> [String: Float]`

- [ ] **Step 1: 실패하는 테스트** `ColorMomentsTests/WordModelTests.swift`
```swift
import XCTest
@testable import ColorMoments

final class WordModelTests: XCTestCase {
    private func head(ids: [String]) -> (Data, Data) {
        let json = try! JSONSerialization.data(withJSONObject: ["format": 1, "wordsVersion": 6, "dim": 2, "ids": ids,
                                                                "mean": [0, 0], "std": [1, 1], "bias": ids.map { _ in 0 }])
        var w: [Float16] = []
        for i in ids.indices { w += [Float16(i == 0 ? 1 : 0), Float16(i == 0 ? 0 : 1)] }
        return (json, w.withUnsafeBufferPointer { Data(buffer: $0) })
    }

    func testScoresAreAMatrixProduct() throws {
        let (j, b) = head(ids: ["a", "b"])
        let h = try WordModel.Head.load(json: j, bin: b, expected: ["a", "b"])
        let s = h.scores([0.2, 0.9])
        XCTAssertEqual(s["a"]!, 0.2, accuracy: 0.01); XCTAssertEqual(s["b"]!, 0.9, accuracy: 0.01)
    }

    func testHeadWithDifferentIDsIsRejected() {
        let (j, b) = head(ids: ["a", "b"])
        XCTAssertThrowsError(try WordModel.Head.load(json: j, bin: b, expected: ["a", "c"]))
    }

    func testBundledHeadMatchesTheWordList() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "WordHead", withExtension: "json"))
        let bin = try XCTUnwrap(Bundle.main.url(forResource: "WordHead", withExtension: "bin"))
        XCTAssertNoThrow(try WordModel.Head.load(json: Data(contentsOf: url), bin: Data(contentsOf: bin),
                                                expected: BundledWordSource.cached.map(\.id)))
    }

    func testExtensionsCarryNoModelOrWordList() throws {
        let plugins = [Bundle.main.builtInPlugInsURL, Bundle.main.bundleURL.appendingPathComponent("Extensions")].compactMap { $0 }
        for dir in plugins {
            for appex in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
                for name in ["WordEncoder.mlmodelc", "WordHead.bin", "words.json", "lunar-days.json"] {
                    XCTAssertFalse(FileManager.default.fileExists(atPath: appex.appendingPathComponent(name).path),
                                   "\(appex.lastPathComponent) 에 \(name) — 확장 크기·메모리")
                }
            }
        }
    }
}
```
- [ ] **Step 2: 구현** `ColorMoments/App/WordModel.swift`
```swift
import Accelerate
import CoreML
import UIKit

/// 학생 모델 = TinyCLIP 인코더(Core ML) + 고르기 층(행렬). 앱 타깃에만 — 확장이 부르면 메모리 한도에 걸린다.
enum WordModel {
    enum LoadError: Error { case badHead, idMismatch }

    struct Head: Sendable {
        let ids: [String], dim: Int, mean: [Float], std: [Float], bias: [Float], weights: [Float]

        static func load(json: Data, bin: Data, expected: [String]) throws -> Head {
            struct Meta: Decodable { let dim: Int; let ids: [String]; let mean: [Float]; let std: [Float]; let bias: [Float] }
            let m = try JSONDecoder().decode(Meta.self, from: json)
            guard m.ids == expected else { throw LoadError.idMismatch }
            let half: [Float16] = bin.withUnsafeBytes { Array($0.bindMemory(to: Float16.self)) }
            guard half.count == m.ids.count * m.dim, m.mean.count == m.dim else { throw LoadError.badHead }
            return Head(ids: m.ids, dim: m.dim, mean: m.mean, std: m.std, bias: m.bias, weights: half.map(Float.init))
        }

        func scores(_ embedding: [Float]) -> [String: Float] {
            var x = zip(zip(embedding, mean), std).map { ($0.0 - $0.1) / $1 }
            var out = bias
            vDSP_mmul(weights, 1, &x, 1, &out, 1, vDSP_Length(ids.count), 1, vDSP_Length(dim))
            vDSP_vadd(out, 1, bias, 1, &out, 1, vDSP_Length(ids.count))
            return Dictionary(uniqueKeysWithValues: zip(ids, out))
        }
    }

    private actor Engine {
        private var encoder: MLModel?
        private var head: Head?

        func load() throws -> (MLModel, Head) {
            if let encoder, let head { return (encoder, head) }
            guard let enc = Bundle.main.url(forResource: "WordEncoder", withExtension: "mlmodelc"),
                  let json = Bundle.main.url(forResource: "WordHead", withExtension: "json"),
                  let bin = Bundle.main.url(forResource: "WordHead", withExtension: "bin") else { throw WordScorer.Failure.unavailable }
            let config = MLModelConfiguration(); config.computeUnits = .cpuAndNeuralEngine
            let model = try MLModel(contentsOf: enc, configuration: config)
            let h = try Head.load(json: Data(contentsOf: json), bin: Data(contentsOf: bin), expected: BundledWordSource.cached.map(\.id))
            encoder = model; head = h
            return (model, h)
        }

        func scores(for image: CGImage) throws -> [String: Float] {
            let (model, head) = try load()
            guard let input = WordImage.input(from: image) else { throw WordScorer.Failure.unavailable }
            let value = try MLFeatureValue(cgImage: input, pixelsWide: WordImage.side, pixelsHigh: WordImage.side,
                                           pixelFormatType: kCVPixelFormatType_32BGRA, options: nil)
            let out = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["image": value]))
            guard let e = out.featureValue(for: "embedding")?.multiArrayValue else { throw WordScorer.Failure.unavailable }
            return head.scores((0..<e.count).map { Float(truncating: e[$0]) })
        }
    }

    private static let engine = Engine()

    static func install() {
        WordScorer.score = { m in
            guard let image = await ShotImage.thumbnail(m, maxPixel: 600)?.cgImage else { throw WordScorer.Failure.unavailable }
            return try await engine.scores(for: image)
        }
        Task.detached(priority: .utility) { _ = try? await engine.load() }
    }
}
```
`vDSP_mmul` 은 `out = W·x` 를 쓰므로 위의 `vDSP_vadd` 로 bias 를 더한다(`out` 초기값은 덮인다). `ColorMomentsApp.swift` 의 시작 지점(지금 `WordAssistant.install()` 이 있던 자리)에 `WordModel.install()`.

`project.yml` 두 확장의 `excludes` 에 `"Word/words.json"`, `"Word/lunar-days.json"` 를 더한다. 확장이 `BundledWordSource` 를 실제로 부르지 않는지 먼저 확인: `grep -rn "BundledWordSource\|WordPicker" ColorMomentsCapture ColorMomentsControl Shared/Widget` 결과가 비어야 한다. 명조 글꼴은 위젯이 조약돌 이름에 쓰므로 빼지 않는다.

모델 파일 3개를 `ColorMoments/App/` 에 둔다(Xcode 가 `.mlpackage` 를 `WordEncoder.mlmodelc` 로 컴파일).
- [ ] **Step 3: 통과 확인** — `xcodegen generate` 후 전체 `test`. Expected: PASS. 앱 번들 크기 확인: `du -sh $(xcodebuild -showBuildSettings … | grep -m1 " BUILT_PRODUCTS_DIR" | awk '{print $3}')/ColorMoments.app` ≈ 20MB 대
- [ ] **Step 4: Commit** — `git commit -m "feat(mongdol): 기기 안 학생 모델 — TinyCLIP 인코더 + 고르기 층(id 목록 대조), 앱 타깃에만, 시작 시 데우기"`

## Sprint 3 — 판정·출시

### Task 8 (공방 운영, PR 없음 — 결과물은 PR-7 의 모델 파일)

- [ ] **Step 1:** 학습 3,000장 선생 답(`answers/qwen35-v4-train`)의 단어를 v6 id 로 옮긴다(단어 글자로 대조). 쉬게 한 단어가 정답인 사진은 뺀다.
- [ ] **Step 2:** `export_encoder.py 8m` → `embed/` 로 사진 값 → `student.py qwen35 --emb coreml-8m` 학습. 같은 방식으로 `39m`.
- [ ] **Step 3:** 처음 보는 사진 30장(최종 판정용)·500장(다양성용)을 학습·평가 날짜와 겹치지 않게 `pick_train.py` 방식으로 뽑아 `extract` 로 판정 후보·사진 값을 만든다.
- [ ] **Step 4:** 학생(8M) 단어를 판정 페이지에 올려 Tabber 블라인드 판정 — 몽돌 47장·처음 보는 30장. 기준: 맞음 ≥ 70%, 틀림 ≤ 7/47·≤ 5/30, 결 있고 맞음 ≥ 40%. 못 넘으면 39M 판정, 그래도 못 넘으면 학습 사진을 늘린다(약 5,600장) → 그래도면 Tabber 와 다시.
- [ ] **Step 5:** 500장에서 서로 다른 단어 수·상위 20개 비중(≤ 50%), 학습 자료에서 정답 3번 이상 단어 수를 회의 기록에 적는다.
- [ ] **Step 6:** 고른 인코더로 `student.py --export ~/mongdol-word-lab/head-v6` → PR-7 에 `WordEncoder.mlpackage`·`WordHead.json`·`WordHead.bin` 을 넣는다.

### Task 9 (PR-8): 문서·고지·설정 문구

**Files:** `Color-Moments/NOTICE`(새), `PRIVACY.md`, `SPEC.md`(§3.5a·§9 단어 흐름), `DESIGN.md`(뜻풀이 두 줄), `ColorMoments/App/SettingsSheet.swift`, `ColorMoments/App/WordRelabelReport.swift`

- [ ] **Step 1:** `NOTICE` — 「단어 뜻풀이: 국립국어원 표준국어대사전, CC BY-SA 2.0 KR(일부는 새로 씀) · 이미지 모델: TinyCLIP (Microsoft, MIT License) 전문」.
- [ ] **Step 2:** `SettingsSheet` 버전 줄 아래(브랜치 `fix/mongdol-dictionary-credit` 머지 뒤) 두 줄:
```swift
            Text("단어는 이 기기 안에서 사진을 보고 고릅니다")
                .font(Face.caption).foregroundStyle(Tone.tertiary)
                .padding(.top, 4)
            Text("단어 뜻풀이 · 국립국어원 표준국어대사전 (CC BY-SA 2.0 KR) · 이미지 모델 TinyCLIP (MIT)")
                .font(Face.caption).foregroundStyle(Tone.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.bottom, 8)
```
(기존 출처 한 줄은 이 두 줄로 바꾼다.)
- [ ] **Step 3:** `PRIVACY.md` 두 줄 — 「단어는 이 기기 안에서 사진을 보고 고릅니다」, 「앱의 단어 모델은 개발자의 사진으로 학습했고, 사용자의 사진은 학습에 쓰지 않습니다」.
- [ ] **Step 4:** `WordRelabelReport` — 사진마다 「규칙 단어 / 학생 단어」를 나란히 보이게(디버그). `WordChooser` 를 `WordScorer` 가 있을 때와 nil 일 때 두 번 불러 비교한다.
- [ ] **Step 5:** 전체 `test` 초록 → Commit `docs(mongdol): 기기 안 단어 모델 — NOTICE·PRIVACY·SPEC·설정 문구`

### Task 10 (출시 — Tabber)

- [ ] TestFlight 빌드(`bundle exec fastlane beta`, 버전은 `project.yml` `MARKETING_VERSION`).
- [ ] iPhone 13: 사진 20장 단어 고르기 시간(첫 로드 따로) — ≤ 0.2초 아니면 「앱이 사진을 받을 때 미리 고르기」로(별도 작은 PR).
- [ ] iPhone 에서 디버그 리포트로 맥과 학생 1등 일치율 ≥ 95%(평가 사진 중 보관함에 있는 것).
- [ ] 처음 여는 내 사진 20장에 붙는 단어를 눈으로 확인.
- [ ] 출시. 회의 기록에 결과를 적는다.

---

## Self-Review

- **Spec coverage:** 흐름(라벨·후보·학생·2초·세 번·↻·조약돌·최근) → Task 5 · 모델 앱 타깃·id 대조·데우기·확장 제외 → Task 7 · 음력 표·윤달·12-last → Task 1·2·3 · v6 데이터(쉬게 하기·뺀 8개 새 id·갈래·뜻풀이) → Task 3 · 같은 전처리·int8·일치율 → Task 6 · 판정 47+30·다양성 500·8M/39M → Task 8 · NOTICE·PRIVACY·설정 → Task 9 · TestFlight·iPhone 13 → Task 10 · WordAssist 빼기 → Task 4.
- **비어 있는 내용:** Task 3 Step 1 의 뜻풀이 새로 쓰기·기존 170개 갈래는 사람 확인이 필요한 내용 작업이라 파일·확인 방법을 정해 두었다.
- **타입 일치:** `WordScorer.score`·`scores(for:within:)`, `WordChooser.choose(... attempts:)`, `WordPicker.modelCandidates(for:in:excluding:banned:pebbleName:)`, `best(_:among:seed:notInGroupOf:)`, `WordModel.Head.load(json:bin:expected:)` — 정의와 사용이 같다.
- **Review Focus:** 다섯 줄 모두 소유 Task 의 테스트에 들어 있다.
