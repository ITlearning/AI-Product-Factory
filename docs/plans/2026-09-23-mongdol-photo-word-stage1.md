# 몽돌 사진 한 단어 — 1단계 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

상태 **completed** · 2026-09-23 · 브랜치 `feat/mongdol-day-gift`

**Goal:** 하루 상세에서 사진을 크게 볼 때, 그 순간의 시간대·계절에 맞는 순우리말 한 단어와 뜻풀이를 보여준다 (AI·위치·날씨 없이).

**Architecture:** 앱 안 `words.json` → `BundledWordSource` → 순수 함수 `WordPicker` 가 `PhotoContext`(시간대·계절)로 후보를 골라 첫 장을 사진에 배정한다. 배정 결과(`PhotoWord`)는 `Moment` 선택 필드로 저장해 다시 열어도 바뀌지 않는다. 화면은 설계 시안 A — 사진 아래 한 덩어리, 좌상단 닫기, 맨 위에서 당기면 닫힘.

**Tech Stack:** Swift 5.10 모드 · SwiftUI · iOS 18.0+ · XCTest · xcodegen · fonttools(pyftsubset)

**Spec:** `docs/designs/mongdol-photo-word.md` (§3 화면, §4 목록, §5 후보, §7 저장, §10 단계 1)

## Global Constraints

- 배포 하한 iOS 18.0. 외부 의존성 추가 금지 (zero deps).
- 단어는 **열린 하루의 사진에만** — `DayPhotoView` 는 `DayMomentsView`(자정 이후 하루)에서만 열린다. 촬영물 뷰어(`ShotViewer`)에는 붙이지 않는다.
- 재촉 금지 — 「단어가 없어요」·로딩 문구 없음. 없으면 그냥 안 보인다.
- 가로 스크롤 금지 (DESIGN §1.3).
- 색·글자 단계는 `Tone`(primary/secondary/tertiary/hairline)과 `Face` 만 쓴다. 새 불투명도 값 금지 (DESIGN §2.1).
- 명조는 서브셋이다. 명조로 찍는 글자가 늘면 **서브셋을 다시 굽는다** (`Shared/Design/Fonts/README.md`). 60KB 미만 유지.
- 해시는 `Hasher`/`hashValue` 금지 — 프로세스마다 시드가 달라 「같은 사진 같은 후보」가 깨진다. FNV-1a 를 쓴다.
- 코드 주석은 함정만 한 줄 ([[feedback-comments-are-noise]]). 「왜」는 커밋 메시지로.
- 단어 `id` 는 한 번 정하면 바꾸지 않는다.

**공통 명령**

```bash
cd /Users/tabber/AI-Product-Factory/Color-Moments
xcodegen generate >/dev/null          # 파일을 추가했을 때
xcodebuild test -project ColorMoments.xcodeproj -scheme ColorMoments \
  -destination 'id=586BD801-ADAD-4A22-B184-451C8B0C91EF' \
  -only-testing:ColorMomentsTests/<TestClass> 2>&1 | grep -E "error:|passed|failed|\*\* TEST"
```

---

## 파일 구조

| 파일 | 책임 |
|---|---|
| `Shared/Word/words.json` (새) | 단어 31개 초안 (spike `wordlab.json` 의 words − 「어스름」 + id) |
| `Shared/Word/WordList.swift` (새) | `TimeBand` · `Season` · `Weather` · `WordEntry` · `WordSource` · `BundledWordSource` |
| `Shared/Word/PhotoContext.swift` (새) | 촬영 시각 → 시간대·계절 |
| `Shared/Word/WordPicker.swift` (새) | 후보 고르기(조건 완화·최근 제외·결정적 섞기), `PhotoWord` 만들기 |
| `Shared/Day/Moment.swift` (수정) | `word: PhotoWord?` 선택 필드 |
| `Shared/Day/DayStore.swift` (수정) | `assignWord`, `recentWordIDs` |
| `Shared/Design/Tokens.swift` (수정) | `Face.word` (명조 30) |
| `Shared/Design/Fonts/*` (수정) | 서브셋 재생성 — 단어 글자 포함 |
| `Shared/Day/DayPhotoView.swift` (수정) | 화면 A · 닫기 방식 · 첫 열람 때 배정 |
| `Shared/Day/DayMomentsView.swift` (수정) | `DayPhotoView` 에 store 전달 |
| `ColorMomentsTests/WordListTests.swift` · `PhotoContextTests.swift` · `WordPickerTests.swift` (새) | |
| `ColorMomentsTests/DayStoreTests.swift` · `FontSubsetTests.swift` (수정) | |

---

### Task 1: 단어 목록과 불러오기

**Files:**
- Create: `Color-Moments/Shared/Word/words.json`
- Create: `Color-Moments/Shared/Word/WordList.swift`
- Test: `Color-Moments/ColorMomentsTests/WordListTests.swift`

**Interfaces:**
- Produces:
  - `public enum TimeBand: String, Codable, Sendable, CaseIterable { case dawn, morning, noon, afternoon, dusk, night }`
  - `public enum Season: String, Codable, Sendable, CaseIterable { case spring, summer, autumn, winter }`
  - `public enum Weather: String, Codable, Sendable, CaseIterable { case clear, cloudy, rain, drizzle, snow, fog, wind }`
  - `public struct WordEntry: Codable, Equatable, Sendable { id, word, meaning: String; times: [TimeBand]; weathers: [Weather]; seasons: [Season] }`
  - `public struct WordList: Codable, Sendable { version: Int; words: [WordEntry] }`
  - `public protocol WordSource: Sendable { func words() async -> [WordEntry] }`
  - `public struct BundledWordSource: WordSource { public init(); public static func load() -> WordList? }`

- [ ] **Step 1: words.json 만들기** — spike 의 words 에 id 를 붙인다. id 는 로마자 표기, 소문자, 공백 없음.
  **「어스름」은 뺀다** — 조약돌 이름이다(`PebbleName.swift`). 초안은 31개.

```bash
cd /Users/tabber/AI-Product-Factory/Color-Moments && mkdir -p Shared/Word && \
git show spike/mongdol-word-ai:Color-Moments/ColorMoments/App/WordLab/wordlab.json | python3 -c '
import json,sys
ids={"윤슬":"yunseul","는개":"neungae","여우비":"yeoubi","해거름":"haegeoreum","개밥바라기":"gaebapbaragi",
"샛별":"saetbyeol","먼동":"meondong","땅거미":"ttanggeomi","이내":"inae","달무리":"dalmuri",
"아지랑이":"ajirangi","꽃샘추위":"kkotsaemchuwi","가랑비":"garangbi","보슬비":"boseulbi","소나기":"sonagi",
"함박눈":"hambaknun","진눈깨비":"jinnunkkaebi","무서리":"museori","산들바람":"sandeulbaram","하늬바람":"hanuibaram",
"된바람":"doenbaram","한낮":"hannat","해맞이":"haemaji","한밤":"hanbam","달맞이":"dalmaji","물보라":"mulbora",
"비설거지":"biseolgeoji","해넘이":"haeneomi","볕바라기":"byeotbaragi","먹장구름":"meokjanggureum","찬바람머리":"chanbarammeori"}
d=json.load(sys.stdin)
out={"version":1,"words":[{"id":ids[w["word"]],**w} for w in d["words"] if w["word"]!="어스름"]}
json.dump(out,open("Shared/Word/words.json","w"),ensure_ascii=False,indent=1)
print(len(out["words"]))'
```

Expected: `31`

- [ ] **Step 2: 실패하는 테스트**

```swift
// ColorMomentsTests/WordListTests.swift
import XCTest
@testable import ColorMoments

final class WordListTests: XCTestCase {

    private func list() throws -> WordList { try XCTUnwrap(BundledWordSource.load(), "words.json 을 못 읽었다") }

    func testBundledListDecodes() throws {
        XCTAssertGreaterThanOrEqual(try list().words.count, 30)
    }

    func testIDsAreUniqueAndStable() throws {
        let ids = try list().words.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "id 가 겹친다 — 사진에 붙은 단어가 엉뚱한 단어로 바뀐다")
        XCTAssertTrue(ids.allSatisfy { $0.range(of: "^[a-z]+$", options: .regularExpression) != nil })
    }

    func testEveryWordHasAMeaning() throws {
        for w in try list().words {
            XCTAssertFalse(w.word.isEmpty); XCTAssertFalse(w.meaning.isEmpty, w.word)
        }
    }

    func testNoWordCollidesWithAPebbleName() throws {
        var pebble = Set<String>()
        for r in stride(from: 0, through: 255, by: 17) {
            for g in stride(from: 0, through: 255, by: 17) {
                for b in stride(from: 0, through: 255, by: 17) {
                    let m = Moment(capturedAt: Date(), colorHex: String(format: "#%02X%02X%02X", r, g, b),
                                   fileName: "x.jpg", source: .app)
                    if let n = PebbleNaming.name(for: [m]) { pebble.insert(n.name) }
                }
            }
        }
        XCTAssertGreaterThan(pebble.count, 15, "색 구간을 훑었는데 이름이 거의 안 나왔다")
        let clash = try list().words.map(\.word).filter(pebble.contains)
        XCTAssertTrue(clash.isEmpty, "조약돌 이름과 겹친다: \(clash)")
    }

    func testSourceReturnsTheSameWords() async throws {
        let a = await BundledWordSource().words()
        XCTAssertEqual(a, try list().words)
    }
}
```


- [ ] **Step 3: 실행 → 실패 확인** — `xcodegen generate` 후 `-only-testing:ColorMomentsTests/WordListTests`. Expected: 컴파일 실패 (`BundledWordSource` 없음).

- [ ] **Step 4: 구현**

```swift
// Shared/Word/WordList.swift
import Foundation

public enum TimeBand: String, Codable, Sendable, CaseIterable { case dawn, morning, noon, afternoon, dusk, night }
public enum Season: String, Codable, Sendable, CaseIterable { case spring, summer, autumn, winter }
public enum Weather: String, Codable, Sendable, CaseIterable { case clear, cloudy, rain, drizzle, snow, fog, wind }

public struct WordEntry: Codable, Equatable, Sendable {
    public let id: String
    public let word: String
    public let meaning: String
    public let times: [TimeBand]
    public let weathers: [Weather]
    public let seasons: [Season]
}

public struct WordList: Codable, Sendable {
    public let version: Int
    public let words: [WordEntry]
}

public protocol WordSource: Sendable {
    func words() async -> [WordEntry]
}

public struct BundledWordSource: WordSource {
    public init() {}

    public static func load() -> WordList? {
        let bundle = Bundle(for: SharedBundleMarker.self)
        guard let url = bundle.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WordList.self, from: data)
    }

    private static let cached = load()?.words ?? []

    public func words() async -> [WordEntry] { Self.cached }
}
```

- [ ] **Step 5: 실행 → 통과 확인.** Expected: `WordListTests` 5개 passed.

- [ ] **Step 6: 커밋**

```bash
cd /Users/tabber/AI-Product-Factory && git add Color-Moments/Shared/Word Color-Moments/ColorMomentsTests/WordListTests.swift Color-Moments/ColorMoments.xcodeproj/project.pbxproj
git commit -m "feat(몽돌): 사진 한 단어 — 우리말 목록과 불러오기 (1단계)"
```

---

### Task 2: 촬영 시각 → 시간대·계절

**Files:**
- Create: `Color-Moments/Shared/Word/PhotoContext.swift`
- Test: `Color-Moments/ColorMomentsTests/PhotoContextTests.swift`

**Interfaces:**
- Consumes: `TimeBand`, `Season`, `Weather` (Task 1)
- Produces: `public struct PhotoContext: Equatable, Sendable { timeBand: TimeBand; season: Season; weather: Weather?; init(date: Date, weather: Weather? = nil, calendar: Calendar = .current) }`, `static func timeBand(hour: Int) -> TimeBand`, `static func season(month: Int) -> Season`

경계 (spike 와 동일): 새벽 04–07 · 아침 07–11 · 한낮 11–15 · 오후 15–17 ·해질녘 17–20 · 밤 20–04. 계절: 3–5 봄 · 6–8 여름 · 9–11 가을 · 12–2 겨울.

- [ ] **Step 1: 실패하는 테스트**

```swift
// ColorMomentsTests/PhotoContextTests.swift
import XCTest
@testable import ColorMoments

final class PhotoContextTests: XCTestCase {

    func testHourBoundaries() {
        let expect: [(Int, TimeBand)] = [(3, .night), (4, .dawn), (6, .dawn), (7, .morning), (10, .morning),
                                         (11, .noon), (14, .noon), (15, .afternoon), (16, .afternoon),
                                         (17, .dusk), (19, .dusk), (20, .night), (23, .night), (0, .night)]
        for (h, band) in expect { XCTAssertEqual(PhotoContext.timeBand(hour: h), band, "\(h)시") }
    }

    func testMonthBoundaries() {
        let expect: [(Int, Season)] = [(2, .winter), (3, .spring), (5, .spring), (6, .summer), (8, .summer),
                                       (9, .autumn), (11, .autumn), (12, .winter), (1, .winter)]
        for (m, s) in expect { XCTAssertEqual(PhotoContext.season(month: m), s, "\(m)월") }
    }

    func testFromDateUsesTheGivenCalendar() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 22; c.hour = 18; c.minute = 20
        let ctx = PhotoContext(date: cal.date(from: c)!, calendar: cal)
        XCTAssertEqual(ctx.timeBand, .dusk)
        XCTAssertEqual(ctx.season, .autumn)
        XCTAssertNil(ctx.weather)
    }
}
```

- [ ] **Step 2: 실행 → 실패 확인** (`xcodegen generate`, `-only-testing:ColorMomentsTests/PhotoContextTests`). Expected: 컴파일 실패.

- [ ] **Step 3: 구현**

```swift
// Shared/Word/PhotoContext.swift
import Foundation

public struct PhotoContext: Equatable, Sendable {
    public let timeBand: TimeBand
    public let season: Season
    public let weather: Weather?

    public init(date: Date, weather: Weather? = nil, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.hour, .month], from: date)
        timeBand = Self.timeBand(hour: c.hour ?? 12)
        season = Self.season(month: c.month ?? 1)
        self.weather = weather
    }

    public static func timeBand(hour: Int) -> TimeBand {
        switch hour {
        case 4..<7: .dawn
        case 7..<11: .morning
        case 11..<15: .noon
        case 15..<17: .afternoon
        case 17..<20: .dusk
        default: .night
        }
    }

    public static func season(month: Int) -> Season {
        switch month {
        case 3...5: .spring
        case 6...8: .summer
        case 9...11: .autumn
        default: .winter
        }
    }
}
```

- [ ] **Step 4: 실행 → 통과 확인.** Expected: 3 passed.

- [ ] **Step 5: 커밋**

```bash
cd /Users/tabber/AI-Product-Factory && git add Color-Moments/Shared/Word/PhotoContext.swift Color-Moments/ColorMomentsTests/PhotoContextTests.swift Color-Moments/ColorMoments.xcodeproj/project.pbxproj
git commit -m "feat(몽돌): 촬영 시각에서 시간대·계절 뽑기"
```

---

### Task 3: 후보 고르기 (WordPicker)

**Files:**
- Create: `Color-Moments/Shared/Word/WordPicker.swift`
- Test: `Color-Moments/ColorMomentsTests/WordPickerTests.swift`

**Interfaces:**
- Consumes: `WordEntry`, `PhotoContext` (Task 1·2)
- Produces:
  - `public struct PhotoWord: Codable, Equatable, Sendable { wordID, word, meaning: String }`
  - `public enum WordPicker`
    - `static func candidates(for ctx: PhotoContext, in words: [WordEntry], excluding recent: Set<String>, seed: String, limit: Int = 8) -> [WordEntry]`
    - `static func photoWord(for ctx: PhotoContext, in words: [WordEntry], excluding recent: Set<String>, seed: String) -> PhotoWord?` — 후보 첫 장
    - `static func fnv1a(_ s: String) -> UInt64`

규칙 (설계 §5):
1. 시간대·계절·날씨가 모두 맞는 단어. 단어의 조건 배열이 비어 있으면 그 칸은 통과. **단어가 날씨를 요구하는데 사진에 날씨가 없으면 불일치.**
2. `recent` 의 id 제외.
3. 0개면 날씨 → 계절 → 시간대 순으로 그 칸 검사를 끄고 다시 (각 단계에서 recent 제외 유지).
4. 조건을 다 꺼도 0개면 recent 제외를 풀고 전체.
5. `fnv1a(seed + ":" + id)` 오름차순으로 섞고 `limit` 개.

- [ ] **Step 1: 실패하는 테스트**

```swift
// ColorMomentsTests/WordPickerTests.swift
import XCTest
@testable import ColorMoments

final class WordPickerTests: XCTestCase {

    private func w(_ id: String, times: [TimeBand] = [], weathers: [Weather] = [], seasons: [Season] = []) -> WordEntry {
        WordEntry(id: id, word: id, meaning: "뜻 \(id)", times: times, weathers: weathers, seasons: seasons)
    }

    private let dusk = PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), calendar: {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }())  // 1970-01-01 18:00 UTC → dusk, winter

    func testFixtureContextIsDuskWinter() {
        XCTAssertEqual(dusk.timeBand, .dusk); XCTAssertEqual(dusk.season, .winter)
    }

    func testMatchesTimeAndSeasonAndTreatsEmptyAsAny() {
        let words = [w("a", times: [.dusk]), w("b", times: [.dawn]), w("c"), w("d", seasons: [.summer])]
        let ids = Set(WordPicker.candidates(for: dusk, in: words, excluding: [], seed: "s").map(\.id))
        XCTAssertEqual(ids, ["a", "c"])
    }

    func testWordNeedingWeatherIsSkippedWhenPhotoHasNone() {
        let words = [w("rainy", weathers: [.rain]), w("any")]
        XCTAssertEqual(WordPicker.candidates(for: dusk, in: words, excluding: [], seed: "s").map(\.id), ["any"])
    }

    func testRecentWordsAreExcluded() {
        let words = [w("a"), w("b"), w("c")]
        let ids = Set(WordPicker.candidates(for: dusk, in: words, excluding: ["a", "b"], seed: "s").map(\.id))
        XCTAssertEqual(ids, ["c"])
    }

    func testRelaxesWeatherBeforeSeasonBeforeTime() {
        let onlyWeather = [w("x", times: [.dusk], weathers: [.snow], seasons: [.winter])]
        XCTAssertEqual(WordPicker.candidates(for: dusk, in: onlyWeather, excluding: [], seed: "s").map(\.id), ["x"],
                       "날씨를 먼저 풀어야 한다")

        let seasonWrong = [w("y", times: [.dusk], seasons: [.summer]), w("z", times: [.dawn], seasons: [.winter])]
        XCTAssertEqual(WordPicker.candidates(for: dusk, in: seasonWrong, excluding: [], seed: "s").map(\.id), ["y"],
                       "계절을 시간대보다 먼저 풀어야 한다 — 해질녘 사진에 새벽 말이 붙으면 안 된다")
    }

    func testFallsBackToEverythingWhenAllAreRecent() {
        let words = [w("a"), w("b")]
        XCTAssertEqual(WordPicker.candidates(for: dusk, in: words, excluding: ["a", "b"], seed: "s").count, 2)
    }

    func testSameSeedSameOrderDifferentSeedCanDiffer() {
        let words = (0..<20).map { w("w\($0)") }
        let a = WordPicker.candidates(for: dusk, in: words, excluding: [], seed: "photo-1").map(\.id)
        let b = WordPicker.candidates(for: dusk, in: words, excluding: [], seed: "photo-1").map(\.id)
        let c = WordPicker.candidates(for: dusk, in: words, excluding: [], seed: "photo-2").map(\.id)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(a.count, 8, "limit 기본 8")
    }

    func testFNVIsStableAcrossRuns() {
        XCTAssertEqual(WordPicker.fnv1a("a"), 0xaf63dc4c8601ec8c, "FNV-1a 64 표준값 — Hasher 로 바꾸면 여기서 깨진다")
    }

    func testPhotoWordCopiesTheFirstCandidate() throws {
        let words = [w("a", times: [.dusk])]
        let pw = try XCTUnwrap(WordPicker.photoWord(for: dusk, in: words, excluding: [], seed: "s"))
        XCTAssertEqual(pw, PhotoWord(wordID: "a", word: "a", meaning: "뜻 a"))
    }

    func testEmptyListGivesNothing() {
        XCTAssertNil(WordPicker.photoWord(for: dusk, in: [], excluding: [], seed: "s"))
    }
}
```

- [ ] **Step 2: 실행 → 실패 확인** (`xcodegen generate`, `-only-testing:ColorMomentsTests/WordPickerTests`). Expected: 컴파일 실패.

- [ ] **Step 3: 구현**

```swift
// Shared/Word/WordPicker.swift
import Foundation

public struct PhotoWord: Codable, Equatable, Sendable {
    public let wordID: String
    public let word: String
    public let meaning: String

    public init(wordID: String, word: String, meaning: String) {
        self.wordID = wordID; self.word = word; self.meaning = meaning
    }
}

public enum WordPicker {

    private struct Check { var weather = true, season = true, time = true }

    private static func matches(_ w: WordEntry, _ ctx: PhotoContext, _ k: Check) -> Bool {
        if k.time, !w.times.isEmpty, !w.times.contains(ctx.timeBand) { return false }
        if k.season, !w.seasons.isEmpty, !w.seasons.contains(ctx.season) { return false }
        if k.weather, !w.weathers.isEmpty {
            guard let weather = ctx.weather, w.weathers.contains(weather) else { return false }
        }
        return true
    }

    public static func candidates(for ctx: PhotoContext, in words: [WordEntry], excluding recent: Set<String>,
                                  seed: String, limit: Int = 8) -> [WordEntry] {
        let steps = [Check(), Check(weather: false), Check(weather: false, season: false),
                     Check(weather: false, season: false, time: false)]
        var found: [WordEntry] = []
        for k in steps {
            found = words.filter { !recent.contains($0.id) && matches($0, ctx, k) }
            if !found.isEmpty { break }
        }
        if found.isEmpty { found = words }
        return Array(found.sorted { fnv1a(seed + ":" + $0.id) < fnv1a(seed + ":" + $1.id) }.prefix(limit))
    }

    public static func photoWord(for ctx: PhotoContext, in words: [WordEntry], excluding recent: Set<String>,
                                 seed: String) -> PhotoWord? {
        candidates(for: ctx, in: words, excluding: recent, seed: seed).first
            .map { PhotoWord(wordID: $0.id, word: $0.word, meaning: $0.meaning) }
    }

    public static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01b3 }
        return h
    }
}
```

- [ ] **Step 4: 실행 → 통과 확인.** Expected: 10 passed.

- [ ] **Step 5: 커밋**

```bash
cd /Users/tabber/AI-Product-Factory && git add Color-Moments/Shared/Word/WordPicker.swift Color-Moments/ColorMomentsTests/WordPickerTests.swift Color-Moments/ColorMoments.xcodeproj/project.pbxproj
git commit -m "feat(몽돌): 사진에 붙일 우리말 후보 고르기 — 조건 완화 순서와 결정적 섞기"
```

---

### Task 4: 사진에 단어 저장

**Files:**
- Modify: `Color-Moments/Shared/Day/Moment.swift`
- Modify: `Color-Moments/Shared/Day/DayStore.swift`
- Test: `Color-Moments/ColorMomentsTests/DayStoreTests.swift`

**Interfaces:**
- Consumes: `PhotoWord` (Task 3)
- Produces:
  - `Moment.word: PhotoWord?` (var, 기본 nil, init 인자 `word: PhotoWord? = nil` 맨 끝)
  - `DayStore.assignWord(_ id: Moment.ID, _ word: PhotoWord)` — 이미 단어가 있으면 **덮어쓰지 않는다**
  - `DayStore.recentWordIDs(excluding id: Moment.ID, limit: Int = 14) -> Set<String>` — 단어가 있는 사진을 촬영 시각 최신순으로 limit 장

- [ ] **Step 1: 실패하는 테스트** — `DayStoreTests` 끝(마지막 `}` 앞)에 추가. 기존 헬퍼 `moment(_:_:name:)`, `date(...)`, `store`, `tempFile` 를 쓴다.

```swift
    func testAssignWordPersistsAndNeverOverwrites() {
        let m = moment(date(2026, 9, 22, 12, 0), name: "w.jpg")
        store.add(m)
        store.assignWord(m.id, PhotoWord(wordID: "neungae", word: "는개", meaning: "가는 비"))
        store.assignWord(m.id, PhotoWord(wordID: "yunseul", word: "윤슬", meaning: "잔물결"))
        XCTAssertEqual(DayStore(fileURL: tempFile).moments.first?.word?.wordID, "neungae",
                       "한 번 붙은 단어가 바뀌면 같은 사진이 뽑기가 된다")
    }

    func testRecentWordIDsAreNewestFirstAndSkipTheAskingPhoto() {
        for i in 0..<5 {
            let m = moment(date(2026, 9, 22, 8 + i, 0), name: "r\(i).jpg")
            store.add(m)
            store.assignWord(m.id, PhotoWord(wordID: "w\(i)", word: "w", meaning: "m"))
        }
        let asking = store.moments.first { $0.fileName == "r4.jpg" }!
        XCTAssertEqual(store.recentWordIDs(excluding: asking.id, limit: 2), ["w3", "w2"])
    }

    func testReadsRecordsSavedBeforeWordsExisted() throws {
        let legacy = """
        [{"id":"\\(UUID().uuidString)","capturedAt":"2026-09-22T03:00:00Z","colorHex":"#AABBCC",
          "fileName":"pre.jpg","source":"app"}]
        """
        try Data(legacy.utf8).write(to: tempFile)
        let m = try XCTUnwrap(DayStore(fileURL: tempFile).moments.first)
        XCTAssertNil(m.word)
        XCTAssertEqual(m.colorHex, "#AABBCC")
    }
```

- [ ] **Step 2: 실행 → 실패 확인** (`-only-testing:ColorMomentsTests/DayStoreTests`). Expected: 컴파일 실패 (`assignWord` 없음).

- [ ] **Step 3: 구현 — Moment**

`Shared/Day/Moment.swift` 에서 `public let source: Source` 다음 줄에 추가:

```swift
    public var word: PhotoWord?
```

init 을 바꾼다:

```swift
    public init(id: UUID = UUID(), capturedAt: Date, colorHex: String,
                fileName: String, source: Source, word: PhotoWord? = nil) {
        self.id = id
        self.capturedAt = capturedAt
        self.colorHex = colorHex
        self.fileName = fileName
        self.source = source
        self.word = word
    }
```

> 합성된 `Decodable` 은 Optional 을 `decodeIfPresent` 로 읽는다 — 옛 기록에 `word` 키가 없어도 된다. 직접 `init(from:)` 을 쓰지 말 것.

- [ ] **Step 4: 구현 — DayStore** (`add(_:)` 아래에)

```swift
    public func assignWord(_ id: Moment.ID, _ word: PhotoWord) {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].word == nil else { return }
        moments[i].word = word
        save()
    }

    public func recentWordIDs(excluding id: Moment.ID, limit: Int = 14) -> Set<String> {
        Set(moments
            .filter { $0.id != id && $0.word != nil }
            .sorted { $0.capturedAt > $1.capturedAt }
            .prefix(limit)
            .compactMap { $0.word?.wordID })
    }
```

- [ ] **Step 5: 실행 → 통과 확인.** 그리고 전체 스위트:

```bash
xcodebuild test -project ColorMoments.xcodeproj -scheme ColorMoments \
  -destination 'id=586BD801-ADAD-4A22-B184-451C8B0C91EF' 2>&1 | grep -E "error:|Executed .* tests.*seconds$|\*\* TEST" | tail -2
```

Expected: `** TEST SUCCEEDED **`. 잠금화면 확장도 `Moment` 를 쓰므로 빌드 확인:

```bash
xcodebuild build -project ColorMoments.xcodeproj -scheme ColorMomentsCapture -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | grep error: ; echo done
```

- [ ] **Step 6: 커밋**

```bash
cd /Users/tabber/AI-Product-Factory && git add Color-Moments/Shared/Day/Moment.swift Color-Moments/Shared/Day/DayStore.swift Color-Moments/ColorMomentsTests/DayStoreTests.swift
git commit -m "feat(몽돌): 사진에 고른 단어를 사본으로 저장 — 한 번 붙으면 안 바뀐다"
```

---

### Task 5: 명조 서브셋에 단어 글자 넣기

**Files:**
- Modify: `Color-Moments/Shared/Design/Fonts/subset-chars.txt`, `NanumMyeongjo-Subset.ttf`, `README.md`
- Modify: `Color-Moments/Shared/Design/Tokens.swift` (`Face.word`)
- Test: `Color-Moments/ColorMomentsTests/FontSubsetTests.swift`

**Interfaces:**
- Produces: `Face.word: Font` — 명조 30

- [ ] **Step 1: 실패하는 테스트** — `testEverySerifGlyphIsPresent` 의 `let missing = ...` 바로 위에 추가:

```swift
        for w in BundledWordSource.load()?.words ?? [] { needed.formUnion(w.word.unicodeScalars) }
```

그리고 새 테스트:

```swift
    func testWordListIsReallyCovered() throws {
        let words = try XCTUnwrap(BundledWordSource.load()?.words)
        XCTAssertGreaterThan(words.count, 0, "단어 목록이 비어 이 검사가 헛돈다")
    }
```

- [ ] **Step 2: 실행 → 실패 확인** (`-only-testing:ColorMomentsTests/FontSubsetTests`). Expected: `testEverySerifGlyphIsPresent` FAIL — 「서브셋에 없는 글자 N개: …」.

- [ ] **Step 3: README 의 글자 뽑기 절차를 단어 목록까지 포함하도록 고친다** — `Shared/Design/Fonts/README.md` 의 python 블록을 이것으로 교체:

```bash
python3 - <<'PY'   # 필요한 글자 뽑기 — 조약돌 이름 + 워드마크 + 사진 한 단어
import re, json, pathlib
src = pathlib.Path("Shared/Day/PebbleName.swift").read_text()
words = json.loads(pathlib.Path("Shared/Word/words.json").read_text())["words"]
chars = set("".join(re.findall(r'name: "([^"]+)"', src))) | set("몽돌") | set("".join(w["word"] for w in words))
pathlib.Path("Shared/Design/Fonts/subset-chars.txt").write_text("".join(sorted(chars)))
PY
```

README 첫 문단의 「조약돌 이름 19개 + 워드마크 「몽돌」에만」을 「조약돌 이름 19개 + 워드마크 「몽돌」 + 사진 한 단어(`Shared/Word/words.json`)에만」으로, 표의 서브셋 글자 수·크기는 Step 4 결과로 고친다. 「`PebbleName.swift` 의 이름이 바뀌면」 문장에 「또는 `words.json` 에 단어가 늘면」을 덧붙인다.

- [ ] **Step 4: 다시 굽기** (Color-Moments 디렉터리에서, README 절차 그대로)

```bash
cd /Users/tabber/AI-Product-Factory/Color-Moments
# Step 3 의 python 블록 실행
curl -L -o /tmp/nm.ttf https://github.com/google/fonts/raw/main/ofl/nanummyeongjo/NanumMyeongjo-Regular.ttf
pyftsubset /tmp/nm.ttf --text-file=Shared/Design/Fonts/subset-chars.txt \
  --output-file=Shared/Design/Fonts/NanumMyeongjo-Subset.ttf \
  --layout-features='' --no-hinting --desubroutinize \
  --name-IDs='0,1,2,3,4,5,6,13,14' --drop-tables+=DSIG
wc -m Shared/Design/Fonts/subset-chars.txt; ls -l Shared/Design/Fonts/NanumMyeongjo-Subset.ttf
```

Expected: 글자 수 100 안팎, 파일 60,000 바이트 미만.

- [ ] **Step 5: `Face.word` 추가** — `Shared/Design/Tokens.swift` 의 `public static let nameHome = serif(23)` 다음 줄:

```swift
    public static let word = serif(30)
```

- [ ] **Step 6: 실행 → 통과 확인.** Expected: `FontSubsetTests` 4 passed (크기 테스트 포함).

- [ ] **Step 7: 커밋**

```bash
cd /Users/tabber/AI-Product-Factory && git add Color-Moments/Shared/Design Color-Moments/ColorMomentsTests/FontSubsetTests.swift
git commit -m "feat(몽돌): 명조 서브셋에 사진 한 단어 글자 추가"
```

---

### Task 6: 사진 크게 보기 — 화면 A

**Files:**
- Modify: `Color-Moments/Shared/Day/DayPhotoView.swift` (전면 교체)
- Modify: `Color-Moments/Shared/Day/DayMomentsView.swift` (`fullScreenCover` 한 줄)

**Interfaces:**
- Consumes: `DayStore.assignWord`, `recentWordIDs` (Task 4) · `WordPicker.photoWord`, `PhotoContext` (Task 2·3) · `BundledWordSource` (Task 1) · `Face.word` (Task 5)
- Produces: `DayPhotoView(momentID: Moment.ID, store: DayStore)`

화면 (설계 §3, 1단계 범위 — 한 줄·동네·날씨·지도 없음):

```
닫기 알약(좌상단, 44pt)          맨 위에서 80pt 이상 당기면 닫힘
[사진] radius 18, 좌우 14, 원본 비율(scaledToFit)
  ↓ 16
는개                             Face.word, primary
안개보다 굵고 이슬비보다 가는 비   11, tertiary
  ↓ 12
● 08:15                          10.5 rounded tertiary, 점 = 그 순간의 색
```

- [ ] **Step 1: DayMomentsView 호출부** — `Shared/Day/DayMomentsView.swift` 에서

```swift
        .fullScreenCover(item: $viewing) { DayPhotoView(moment: $0) }
```

를

```swift
        .fullScreenCover(item: $viewing) { DayPhotoView(momentID: $0.id, store: store) }
```

로.

- [ ] **Step 2: DayPhotoView 교체**

```swift
import SwiftUI
import UIKit

struct DayPhotoView: View {
    let momentID: Moment.ID
    let store: DayStore

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    private var moment: Moment? { store.moments.first { $0.id == momentID } }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Tone.pure.ignoresSafeArea()
            if let moment {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 60)
                        photo(moment)
                        Spacer().frame(height: 16)
                        words(moment).padding(.horizontal, 26)
                        Spacer().frame(height: 40)
                    }
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in
                    if y < -80 { dismiss() }
                }
                .task(id: moment.fileName) { await load(moment) }
                .task(id: moment.id) { await assignWordIfNeeded(moment) }
            }
            closeButton.padding(.leading, 18).padding(.top, 8)
        }
        .statusBarHidden()
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Text("닫기")
                .font(.system(size: 13))
                .foregroundStyle(Tone.primary)
                .padding(.horizontal, 16)
                .frame(minHeight: Shape2.minTouch)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func photo(_ m: Moment) -> some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color(hex: m.colorHex).aspectRatio(3 / 4, contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Shape2.photoWindow, style: .continuous))
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func words(_ m: Moment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let w = m.word {
                Text(w.word).font(Face.word).foregroundStyle(Tone.primary)
                Spacer().frame(height: 4)
                Text(w.meaning).font(.system(size: 11)).foregroundStyle(Tone.tertiary)
                Spacer().frame(height: 12)
            }
            HStack(spacing: 6) {
                Circle().fill(Color(hex: m.colorHex)).frame(width: 9, height: 9)
                Text(DayGradient.timeText(m.capturedAt))
                    .font(.system(size: 10.5, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Tone.tertiary)
            }
        }
        .animation(.easeOut(duration: 0.25), value: m.word)
    }

    private func load(_ m: Moment) async {
        let name = m.fileName
        image = await Task.detached(priority: .userInitiated) { ShotImage.full(name) }.value
    }

    private func assignWordIfNeeded(_ m: Moment) async {
        guard m.word == nil else { return }
        let words = await BundledWordSource().words()
        let recent = store.recentWordIDs(excluding: m.id)
        guard let pw = WordPicker.photoWord(for: PhotoContext(date: m.capturedAt), in: words,
                                            excluding: recent, seed: m.id.uuidString) else { return }
        store.assignWord(m.id, pw)
    }
}
```

> `onScrollGeometryChange` 는 iOS 18 API. `contentOffset.y + contentInsets.top` 이 음수면 위로 당긴 것.

- [ ] **Step 3: 빌드 + 전체 테스트**

```bash
cd /Users/tabber/AI-Product-Factory/Color-Moments
xcodebuild test -project ColorMoments.xcodeproj -scheme ColorMoments \
  -destination 'id=586BD801-ADAD-4A22-B184-451C8B0C91EF' 2>&1 | grep -E "error:|Executed .* tests.*seconds$|\*\* TEST" | tail -2
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: 시뮬레이터 화면 확인** — 탭 도구(idb)가 없으므로 **커밋하지 않는 임시 훅**으로 연다. `HomeView` 의 `.sheet(item: $opened)` 앞에 `.onAppear { if let k = days.first { opened = OpenedDay(id: k) } }`, `DayMomentsView` 의 `.presentationDragIndicator(.hidden)` 뒤에 `.onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { viewing = moments.last } }` 를 넣고 빌드·설치·스크린샷 → **두 훅을 되돌린다** → `git diff --stat` 로 훅이 남지 않았는지 확인.
  - 확인할 것: 단어가 **명조**로 찍히는지(SF로 떨어지면 Task 5 실패), 뜻풀이·시각 줄, 닫기 알약.
  - 앱을 두 번 열어 같은 사진의 단어가 **같은지**.

- [ ] **Step 5: 커밋**

```bash
cd /Users/tabber/AI-Product-Factory && git add Color-Moments/Shared/Day/DayPhotoView.swift Color-Moments/Shared/Day/DayMomentsView.swift
git commit -m "feat(몽돌): 사진 크게 보기에 우리말 한 단어 — 화면 A, 닫기 알약·당겨 닫기"
```

---

### Task 7: 문서 반영

**Files:**
- Modify: `Color-Moments/DESIGN.md` §4.5 (진행표에 「사진 한 단어 1단계」 행)
- Modify: `Color-Moments/SPEC.md` §3.5 (사진 탭 → 크게 보기 + 한 단어)
- Modify: `docs/designs/mongdol-photo-word.md` (상태 → 「1단계 구현」, §10 1단계 ✅)
- Modify: 이 계획 문서 상태 → completed

- [ ] **Step 1: 세 문서 수정** — 경로·행동 변화만. 「설계에서 벗어난 곳」이 생겼으면 DESIGN §4.5 에 근거와 함께.
- [ ] **Step 2: DOC_LINT** — `docs/process/DOC_LINT.md` 체크리스트 수행 (링크·경로 실재).
- [ ] **Step 3: 커밋**

```bash
cd /Users/tabber/AI-Product-Factory && git add Color-Moments/DESIGN.md Color-Moments/SPEC.md docs/designs/mongdol-photo-word.md docs/plans/2026-09-23-mongdol-photo-word-stage1.md
git commit -m "docs(몽돌): 사진 한 단어 1단계 반영"
```

---

## 수동 확인 (Tabber, 실기기)

- [ ] 열린 하루에서 사진을 누르면 단어·뜻풀이·시각이 보인다
- [ ] 단어가 명조로 보인다
- [ ] 같은 사진을 다시 열어도 같은 단어다
- [ ] 연달아 여러 사진을 열 때 같은 단어가 연속으로 반복되지 않는다
- [ ] 닫기 알약, 맨 위에서 당겨 닫기 둘 다 된다
- [ ] 오늘 찍은 사진(촬영물 뷰어)에는 단어가 없다
