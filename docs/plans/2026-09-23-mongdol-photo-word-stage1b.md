# 몽돌 사진 한 단어 — 1단계 보강 (사진을 보고 고르기 + 확대 전환) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

상태 **executing** · 2026-09-23 · 브랜치 `feat/mongdol-day-gift` · 앞 계획 `2026-09-23-mongdol-photo-word-stage1.md`

**Goal:** 단어를 촬영 시각이 아니라 **사진에 찍힌 것**(기기 안 Vision 분류)으로 고르고, 맞는 말이 없으면 비워 둔다. 크게 보기는 사진 앱처럼 확대·축소 전환으로 연다.

**Why:** 1단계 결과를 본 Tabber 판정 — 「사진은 사진인데 글은 쌩뚱맞게 뜬다」. 원인은 단어가 사진을 한 번도 안 보고 시간대로만 골라졌기 때문. 16장 실측에서 야외 사진은 Vision 분류가 정확했다(하늘·바다·꽃·구름·도시), 실내는 분류가 적어 일상 단어를 추가.

**Tech Stack:** Swift 5.10 · SwiftUI · iOS 18 · Vision(`VNClassifyImageRequest`) · XCTest · xcodegen · fontTools

**Spec:** `docs/designs/mongdol-photo-word.md` (이 계획 끝에서 §5 를 갱신)

## Global Constraints

- iOS 18.0 하한, 외부 의존성 0. Vision 은 시스템 프레임워크.
- **사진은 기기 밖으로 나가지 않는다.** Vision 은 기기 안에서만 돈다.
- 단어는 열린 하루의 사진에만. 재촉 문구 없음. 맞는 말이 없으면 **아무것도 안 보인다**.
- **한 번 붙은 단어는 바뀌지 않는다.** 단 `labels` 없이 붙은 단어(옛 규칙)는 불러올 때 지운다.
- 색·글자는 `Tone`/`Face` 만. 해시는 FNV-1a(`Hasher` 금지). 주석은 함정만 한 줄.
- 정밀도 기준: `hasMinimumRecall(0.01, forPrecision: 0.9)` 를 통과한 분류만 쓴다.
- **테스트는 항상 시간 제한**: `perl -e 'alarm 240; exec @ARGV' xcodebuild test ...`. 멈추면 `xcrun simctl shutdown <id> && xcrun simctl boot <id>` 후 재시도, 또 멈추면 다른 시뮬레이터로.
- 시뮬레이터: 메인 트리 `586BD801-ADAD-4A22-B184-451C8B0C91EF`, 병렬 worktree `0E276ADC-03B7-4937-82AF-682DED81DBE4`.

```bash
cd /Users/tabber/AI-Product-Factory/Color-Moments
xcodegen generate >/dev/null   # 새 파일을 만들었을 때만
perl -e 'alarm 240; exec @ARGV' xcodebuild test -project ColorMoments.xcodeproj -scheme ColorMoments \
  -destination 'id=586BD801-ADAD-4A22-B184-451C8B0C91EF' -only-testing:ColorMomentsTests/<Class> 2>&1 \
  | grep -E "error:|passed|failed|\*\* TEST"
```

---

### Task 1: 단어 목록 v2 — 어울리는 대상(subjects)

**Files:** Modify `Color-Moments/Shared/Word/words.json`, `Color-Moments/Shared/Word/WordList.swift`, `Color-Moments/ColorMomentsTests/WordListTests.swift`

**Produces:** `WordEntry.subjects: [String]` (Vision identifier, 비어 있으면 그 단어는 쉰다)

- [ ] **Step 1:** 준비된 목록으로 교체 — `cp /Users/tabber/AI-Product-Factory/.superpowers/sdd/2026-09-23-mongdol-photo-word-stage1b/words.json Color-Moments/Shared/Word/words.json` (49개, version 2. 모든 subject 는 Vision 1,303 분류 중 실재하는 이름으로 검증됨)
- [ ] **Step 2: 실패하는 테스트** — `WordListTests` 에 추가:

```swift
    func testMostWordsHaveSubjects() throws {
        let words = try list().words
        XCTAssertGreaterThan(words.filter { !$0.subjects.isEmpty }.count, 40,
                             "대상이 없는 단어는 쉰다 — 대부분은 대상이 있어야 한다")
    }

    func testEverySubjectIsARealVisionLabel() throws {
        let supported: Set<String>
        do { supported = Set(try VNClassifyImageRequest().supportedIdentifiers()) }
        catch { throw XCTSkip("이 환경에서 Vision 분류 목록을 못 읽는다: \(error)") }
        let bad = try list().words.flatMap { w in w.subjects.filter { !supported.contains($0) }.map { "\(w.word):\($0)" } }
        XCTAssertTrue(bad.isEmpty, "Vision 에 없는 분류 이름 — 이 단어는 영영 안 나온다: \(bad)")
    }
```

파일 맨 위에 `import Vision` 추가. Step 3 전에 실행 → `subjects` 가 없어 컴파일 실패.

- [ ] **Step 3: 구현** — `WordEntry` 에 `public let subjects: [String]` 를 `seasons` 다음에 추가. 기존 테스트의 `WordEntry(...)` 호출(WordPickerTests 헬퍼)은 Task 3 에서 고치므로, 이 과제에서는 `WordPickerTests.swift` 헬퍼 `w(...)` 에 `subjects: [String] = []` 매개변수를 추가하고 `WordEntry(..., seasons: seasons, subjects: subjects)` 로만 바꿔 컴파일을 맞춘다.
- [ ] **Step 4:** `WordListTests` 전부 통과 + 전체 스위트(시간 제한). `testEverySubjectIsARealVisionLabel` 이 시뮬레이터에서 skip 되면 그대로 두고 보고서에 적는다.
- [ ] **Step 5: 커밋** `feat(몽돌): 단어마다 어울리는 사진 대상 — 일상 말 18개 추가 (49개)`

---

### Task 2: 사진 분류 + 저장

**Files:** Create `Color-Moments/Shared/Word/PhotoLabeler.swift`; Modify `Color-Moments/Shared/Day/Moment.swift`, `Color-Moments/Shared/Day/DayStore.swift`, `Color-Moments/Shared/Word/WordList.swift`; Test `Color-Moments/ColorMomentsTests/PhotoLabelerTests.swift`, `Color-Moments/ColorMomentsTests/DayStoreTests.swift`

**Produces:**
- `PhotoLabeler.labels(for image: CGImage) -> [String]?` — nil = 분류 실패(다음에 다시), [] = 분류했지만 확실한 것 없음
- `PhotoLabeler.labels(forShot fileName: String) -> [String]?` — `ShotImage.thumbnail(_:maxPixel: 600)` 로 줄여서
- `Weather.inferred(from labels: Set<String>) -> Weather?` — snow → .snow, cloudy → .cloudy, blue_sky → .clear, 그 외 nil (이 우선순위)
- `Moment.labels: [String]?` (init 끝에 `labels: [String]? = nil`)
- `DayStore.setLabels(_ id: Moment.ID, _ labels: [String])` — 이미 있으면 덮어쓰지 않음
- `DayStore.load()` — 불러온 뒤 `labels == nil` 인 사진의 `word` 를 nil 로 (옛 규칙으로 붙은 단어 정리)

- [ ] **Step 1: 실패하는 테스트**

```swift
// ColorMomentsTests/PhotoLabelerTests.swift
import XCTest
import UIKit
@testable import ColorMoments

final class PhotoLabelerTests: XCTestCase {

    private func fixture(_ name: String) throws -> CGImage {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "jpg", subdirectory: "Fixtures"))
        return try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
    }

    func testBlossomPhotoIsRecognised() throws {
        guard let labels = PhotoLabeler.labels(for: try fixture("IMG_5005")) else {
            throw XCTSkip("이 환경에서 Vision 분류가 돌지 않는다")
        }
        XCTAssertTrue(Set(labels).isSuperset(of: ["flower"]) || labels.contains("blossom"),
                      "벚꽃 사진(IMG_5005)인데 꽃이 안 잡혔다: \(labels)")
    }

    func testWeatherFromLabels() {
        XCTAssertEqual(Weather.inferred(from: ["sky", "snow", "cloudy"]), .snow)
        XCTAssertEqual(Weather.inferred(from: ["sky", "cloudy", "blue_sky"]), .cloudy)
        XCTAssertEqual(Weather.inferred(from: ["blue_sky"]), .clear)
        XCTAssertNil(Weather.inferred(from: ["laptop"]), "사진으로 알 수 없으면 모른다고 둔다")
    }
}
```

`DayStoreTests` 끝에 추가:

```swift
    func testLabelsPersistAndNeverOverwrite() {
        let m = moment(date(2026, 9, 22, 12, 0), name: "l.jpg")
        store.add(m)
        store.setLabels(m.id, ["sky"])
        store.setLabels(m.id, ["laptop"])
        XCTAssertEqual(DayStore(fileURL: tempFile).moments.first?.labels, ["sky"])
    }

    func testWordWithoutLabelsIsDroppedOnLoad() throws {
        let legacy = """
        [{"id":"\\(UUID().uuidString)","capturedAt":"2026-09-22T03:00:00Z","colorHex":"#AABBCC","fileName":"a.jpg","source":"app",
          "word":{"wordID":"haegeoreum","word":"해거름","meaning":"m"}},
         {"id":"\\(UUID().uuidString)","capturedAt":"2026-09-22T04:00:00Z","colorHex":"#AABBCC","fileName":"b.jpg","source":"app",
          "labels":["sky"],"word":{"wordID":"meondong","word":"먼동","meaning":"m"}}]
        """
        try Data(legacy.utf8).write(to: tempFile)
        let ms = DayStore(fileURL: tempFile).moments.sorted { $0.fileName < $1.fileName }
        XCTAssertNil(ms[0].word, "사진을 안 보고 붙은 옛 단어는 지운다")
        XCTAssertEqual(ms[1].word?.wordID, "meondong", "사진을 보고 붙은 단어는 그대로")
    }
```

`xcodegen generate` 후 실행 → 컴파일 실패 확인.

- [ ] **Step 2: 구현**

```swift
// Shared/Word/PhotoLabeler.swift
import CoreGraphics
import Vision

public enum PhotoLabeler {

    public static func labels(for image: CGImage) -> [String]? {
        let request = VNClassifyImageRequest()
        do { try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request]) } catch { return nil }
        return (request.results ?? [])
            .filter { $0.hasMinimumRecall(0.01, forPrecision: 0.9) }
            .map(\.identifier)
    }

    public static func labels(forShot fileName: String) -> [String]? {
        // thumbnail 은 EXIF 방향을 이미 적용한다 — 그래서 .up
        guard let image = ShotImage.thumbnail(fileName, maxPixel: 600)?.cgImage else { return nil }
        return labels(for: image)
    }
}
```

`Shared/Word/WordList.swift` 에:

```swift
public extension Weather {
    static func inferred(from labels: Set<String>) -> Weather? {
        if labels.contains("snow") { return .snow }
        if labels.contains("cloudy") { return .cloudy }
        if labels.contains("blue_sky") { return .clear }
        return nil
    }
}
```

`Moment`: `public var word: PhotoWord?` 다음에 `public var labels: [String]?`; init 끝에 `labels: [String]? = nil` 과 `self.labels = labels`.

`DayStore`:

```swift
    public func setLabels(_ id: Moment.ID, _ labels: [String]) {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].labels == nil else { return }
        moments[i].labels = labels
        save()
    }
```

`load()` 의 `moments = (try? decoder.decode([Moment].self, from: data)) ?? []` 를:

```swift
        let decoded = (try? decoder.decode([Moment].self, from: data)) ?? []
        moments = decoded.map { m in
            var m = m
            if m.labels == nil { m.word = nil }
            return m
        }
```

- [ ] **Step 3:** `PhotoLabelerTests`, `DayStoreTests` 통과 → 전체 스위트 → 캡처 확장 빌드(`-scheme ColorMomentsCapture -destination 'generic/platform=iOS Simulator'`). Vision 테스트가 skip 되면 보고서에 적는다.
- [ ] **Step 4: 커밋** `feat(몽돌): 사진 분류(Vision, 기기 안) 저장 · 사진을 안 보고 붙은 옛 단어 정리`

---

### Task 3: 고르기 규칙 — 대상이 맞아야 붙는다

**Files:** Modify `Color-Moments/Shared/Word/WordPicker.swift`, `Color-Moments/ColorMomentsTests/WordPickerTests.swift`

**Consumes:** `WordEntry.subjects`, `PhotoContext`, `Weather`
**Produces:** `candidates(for ctx: PhotoContext, labels: Set<String>, in: [WordEntry], excluding: Set<String>, seed: String, limit: Int = 8)` · `photoWord(for:labels:in:excluding:seed:)` — 기존 `labels` 없는 두 함수는 **지운다**.

규칙:
1. 후보 = `subjects` 가 비어 있지 않고 `labels` 와 하나라도 겹치는 단어. 없으면 **빈 배열**.
2. 사진에 날씨가 없으면(`ctx.weather == nil`) 날씨 조건이 붙은 단어는 뺀다.
3. 단계: [시간·계절·날씨 모두] → [날씨 끔] → [계절 끔]. **시간대는 끄지 않는다.** 각 단계에서 recent 제외.
4. 셋 다 비면 같은 단계를 recent 제외 없이 다시.
5. 그래도 비면 빈 배열.
6. FNV-1a 섞기·limit 은 그대로.

- [ ] **Step 1: 테스트 교체** — `WordPickerTests.swift` 를 아래로 통째로 교체:

```swift
import XCTest
@testable import ColorMoments

final class WordPickerTests: XCTestCase {

    private func w(_ id: String, times: [TimeBand] = [], weathers: [Weather] = [], seasons: [Season] = [],
                   subjects: [String] = ["sky"]) -> WordEntry {
        WordEntry(id: id, word: id, meaning: "뜻 \(id)", times: times, weathers: weathers, seasons: seasons, subjects: subjects)
    }

    private let utc: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    private var dusk: PhotoContext { PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), calendar: utc) } // 1970-01-01 18:00 → dusk, winter
    private func pick(_ ctx: PhotoContext, _ labels: Set<String>, _ words: [WordEntry], recent: Set<String> = []) -> [String] {
        WordPicker.candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: "s").map(\.id)
    }

    func testFixtureIsDuskWinter() { XCTAssertEqual(dusk.timeBand, .dusk); XCTAssertEqual(dusk.season, .winter) }

    func testOnlyWordsWhoseSubjectIsInThePhoto() {
        let words = [w("sea", subjects: ["ocean"]), w("desk", subjects: ["laptop"]), w("idle", subjects: [])]
        XCTAssertEqual(pick(dusk, ["ocean", "sky"], words), ["sea"])
    }

    func testNothingFitsMeansNothing() {
        XCTAssertEqual(pick(dusk, ["laptop"], [w("sea", subjects: ["ocean"])]), [], "맞는 말이 없으면 비워 둔다")
        XCTAssertEqual(pick(dusk, [], [w("sea", subjects: ["ocean"])]), [])
    }

    func testTimeBandIsNeverRelaxed() {
        let words = [w("dawnword", times: [.dawn])]
        XCTAssertEqual(pick(dusk, ["sky"], words), [], "해질녘 하늘에 새벽 말이 붙으면 안 된다")
    }

    func testSeasonRelaxesWhenNothingElseFits() {
        XCTAssertEqual(pick(dusk, ["sky"], [w("summerword", seasons: [.summer])]), ["summerword"])
    }

    func testWeatherlessPhotoSkipsWeatherWords() {
        let words = [w("rainy", weathers: [.rain]), w("plain")]
        XCTAssertEqual(pick(dusk, ["sky"], words), ["plain"])
        XCTAssertEqual(pick(dusk, ["sky"], [w("rainy", weathers: [.rain])]), [], "날씨를 모르면 날씨 말은 끝까지 안 쓴다")
    }

    func testKnownWeatherMatchesAndRelaxesBeforeSeason() {
        let snowy = PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), weather: .snow, calendar: utc)
        XCTAssertEqual(pick(snowy, ["snow"], [w("snowword", weathers: [.snow], subjects: ["snow"])]), ["snowword"])
        let words = [w("p", weathers: [.rain], seasons: [.winter]), w("q", weathers: [.fog], seasons: [.summer])]
        XCTAssertEqual(pick(snowy, ["sky"], words), ["p"], "날씨를 계절보다 먼저 푼다")
    }

    func testRecentIsExcludedThenReleased() {
        let words = [w("a"), w("b")]
        XCTAssertEqual(pick(dusk, ["sky"], words, recent: ["a"]), ["b"])
        XCTAssertEqual(Set(pick(dusk, ["sky"], words, recent: ["a", "b"])), ["a", "b"], "다 최근이면 반복을 허용한다")
    }

    func testSameSeedSameOrderAndLimit() {
        let words = (0..<20).map { w("w\($0)") }
        let a = WordPicker.candidates(for: dusk, labels: ["sky"], in: words, excluding: [], seed: "photo-1").map(\.id)
        let b = WordPicker.candidates(for: dusk, labels: ["sky"], in: words, excluding: [], seed: "photo-1").map(\.id)
        let c = WordPicker.candidates(for: dusk, labels: ["sky"], in: words, excluding: [], seed: "photo-2").map(\.id)
        XCTAssertEqual(a, b); XCTAssertNotEqual(a, c); XCTAssertEqual(a.count, 8)
    }

    func testFNVIsStableAcrossRuns() {
        XCTAssertEqual(WordPicker.fnv1a("a"), 0xaf63dc4c8601ec8c)
    }

    func testPhotoWordCopiesTheFirstCandidate() throws {
        let pw = try XCTUnwrap(WordPicker.photoWord(for: dusk, labels: ["sky"], in: [w("a")], excluding: [], seed: "s"))
        XCTAssertEqual(pw, PhotoWord(wordID: "a", word: "a", meaning: "뜻 a"))
    }
}
```

실행 → 컴파일 실패(`labels:` 인자 없음) 확인.

- [ ] **Step 2: 구현** — `candidates` 와 `photoWord` 를 교체:

```swift
    public static func candidates(for ctx: PhotoContext, labels: Set<String>, in words: [WordEntry],
                                  excluding recent: Set<String>, seed: String, limit: Int = 8) -> [WordEntry] {
        var pool = words.filter { !$0.subjects.isEmpty && !labels.isDisjoint(with: $0.subjects) }
        // 날씨를 모르는 사진에 날씨 말이 붙으면 영구히 틀린 채 남는다.
        if ctx.weather == nil { pool = pool.filter { $0.weathers.isEmpty } }
        let steps = [Check(), Check(weather: false), Check(weather: false, season: false)]
        for skipRecent in [true, false] {
            for k in steps {
                let found = pool.filter { !(skipRecent && recent.contains($0.id)) && matches($0, ctx, k) }
                if !found.isEmpty {
                    return Array(found.sorted { fnv1a(seed + ":" + $0.id) < fnv1a(seed + ":" + $1.id) }.prefix(limit))
                }
            }
        }
        return []
    }

    public static func photoWord(for ctx: PhotoContext, labels: Set<String>, in words: [WordEntry],
                                 excluding recent: Set<String>, seed: String) -> PhotoWord? {
        candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: seed).first
            .map { PhotoWord(wordID: $0.id, word: $0.word, meaning: $0.meaning) }
    }
```

`Check` 의 `time` 필드는 이제 항상 true 로만 쓰이지만 `matches` 는 그대로 둔다.

- [ ] **Step 3:** `WordPickerTests` 통과. `DayPhotoView.swift` 가 옛 `photoWord(for:in:excluding:seed:)` 를 부르므로 **전체 빌드는 Task 4 전까지 깨진다** — 이 과제에서는 `DayPhotoView.assignWordIfNeeded` 의 호출 한 줄만 `labels: []` 를 넘기도록 고쳐 빌드를 맞춘다(Task 4 가 제대로 연결). 그 뒤 전체 스위트.
- [ ] **Step 4: 커밋** `feat(몽돌): 사진에 찍힌 것과 맞는 말만 — 없으면 비워 둔다`

---

### Task 4: 화면 연결 + 사진 앱 같은 확대 전환

**Files:** Modify `Color-Moments/Shared/Day/DayPhotoView.swift`, `Color-Moments/Shared/Day/DayMomentsView.swift`

- [ ] **Step 1: DayMomentsView** — `@Namespace private var zoom` 추가. 시간축의 `Button { viewing = p.moment } label: { photoCard(p.moment) }` 에서 `photoCard(p.moment)` 뒤에 `.matchedTransitionSource(id: p.moment.id, in: zoom)`. `fullScreenCover` 를:

```swift
        .fullScreenCover(item: $viewing) { m in
            DayPhotoView(momentID: m.id, store: store)
                .navigationTransition(.zoom(sourceID: m.id, in: zoom))
        }
```

- [ ] **Step 2: DayPhotoView**
  - `@State private var dismissing` 와 `.onScrollGeometryChange(...)` 블록을 **지운다** — 확대 전환의 기본 쓸어내리기가 대신한다.
  - `assignWordIfNeeded` 교체:

```swift
    private func assignWordIfNeeded(_ m: Moment) async {
        guard m.word == nil else { return }
        var labels = m.labels
        if labels == nil {
            let name = m.fileName
            labels = await Task.detached(priority: .userInitiated) { PhotoLabeler.labels(forShot: name) }.value
            guard let labels else { return }
            store.setLabels(m.id, labels)
        }
        let seen = Set(labels ?? [])
        let words = await BundledWordSource().words()
        let ctx = PhotoContext(date: m.capturedAt, weather: Weather.inferred(from: seen))
        guard let pw = WordPicker.photoWord(for: ctx, labels: seen, in: words,
                                            excluding: store.recentWordIDs(excluding: m.id), seed: m.id.uuidString) else { return }
        store.assignWord(m.id, pw)
    }
```

- [ ] **Step 3:** 전체 스위트(시간 제한) 통과.
- [ ] **Step 4: 시뮬레이터 확인** — 커밋하지 않는 임시 훅으로 연다(앞 계획 Task 6 Step 4 와 같은 방법: `HomeView` 의 `.sheet(item: $opened)` 앞에 첫 하루 자동 열기, `DayMomentsView` 에서 1초 뒤 `viewing = moments.last`). 스크린샷 `/private/tmp/claude-501/-Users-tabber-AI-Product-Factory/e2c9c186-d007-4b02-a2ca-82140078b1b4/scratchpad/stage1b-photo.png`. 시뮬레이터 예시 사진은 파일이 없어 분류가 nil → 단어가 **안 보이는 게 정상**. 훅을 되돌리고 `git diff --stat` 로 두 파일만 남았는지 확인.
- [ ] **Step 5: 커밋** `feat(몽돌): 사진 크게 보기를 확대 전환으로 · 사진을 보고 단어 배정`

---

### Task 5: 명조 서브셋 다시 굽기

**Files:** `Color-Moments/Shared/Design/Fonts/subset-chars.txt`, `NanumMyeongjo-Subset.ttf`, `README.md`(표의 글자 수·크기만)

- [ ] **Step 1:** `FontSubsetTests` 실행 → 새 단어 글자가 없어 실패 확인.
- [ ] **Step 2:** `Shared/Design/Fonts/README.md` 절차 그대로 다시 굽는다. `pyftsubset` 셔뱅이 깨져 있으면 `python3 -m fontTools.subset` 으로 같은 인자.
- [ ] **Step 3:** `FontSubsetTests` 통과(60KB 미만), 전체 스위트.
- [ ] **Step 4: 커밋** `feat(몽돌): 명조 서브셋에 일상 단어 글자 추가`

---

### Task 6: 문서

- `docs/designs/mongdol-photo-word.md` §5 를 이 계획의 규칙(대상 일치 필수 · 없으면 비움 · 시간대는 안 풂 · 날씨는 Vision 파란 하늘/구름/눈에서 추정 · 옛 단어 정리)으로 고치고, §4 JSON 예시에 `"subjects"` 추가. §3 에 「확대 전환(matchedTransitionSource + navigationTransition(.zoom)) — 쓸어내리면 시간축 카드로 돌아간다」.
- `Color-Moments/DESIGN.md` §4.5 행 8 을 「사진 한 단어 1단계 — 사진을 보고 고름(Vision)」으로.
- `Color-Moments/SPEC.md` §3.5a 문장을 「단어는 처음 열 때 사진에 찍힌 것(기기 안 Vision)과 시간대·계절로 고르고, 맞는 말이 없으면 비워 둔다. 쓸어내리면 시간축의 사진 자리로 줄어든다」로.
- 이 계획 상태 → completed.
- 커밋 `docs(몽돌): 사진을 보고 고르는 단어 규칙 반영`

## 수동 확인 (Tabber, 실기기)

- [ ] 사진을 누르면 시간축 카드에서 커지고, 쓸어내리면 그 자리로 줄어든다
- [ ] 쓸어내리기가 크게 보기 안의 세로 스크롤과 부딪히지 않는다
- [ ] 바다·하늘·꽃·음식 사진에 사진과 이어지는 말이 붙는다
- [ ] 맞는 말이 없는 사진은 단어 없이 사진·시각만 보인다
- [ ] 1단계 때 붙었던 단어(시간대로만 고른 것)는 사라지고, 다시 열면 사진을 보고 새로 고른다
