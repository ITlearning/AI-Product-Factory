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

    func testNothingInThePhotoFallsBackToTheMoment() {
        let words = [w("sea", subjects: ["ocean"]), w("duskword", times: [.dusk], subjects: []).asMoment,
                     w("moonhalo", times: [.dusk], subjects: ["moon"])]
        XCTAssertEqual(pick(dusk, ["laptop"], words), ["duskword"], "맞는 대상이 없으면 그 때의 말로 — 비워 두지 않는다")
        XCTAssertEqual(pick(dusk, [], words), ["duskword"])
    }

    func testMomentFallbackPrefersRealWeatherThenTimeThenSeason() {
        let rainy = PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), weather: .rain, calendar: utc)
        let words = [w("rainword", weathers: [.rain], subjects: []).asMoment,
                     w("duskword", times: [.dusk], subjects: []).asMoment,
                     w("winterword", seasons: [.winter], subjects: []).asMoment]
        XCTAssertEqual(pick(rainy, ["laptop"], words).first, "rainword")
        XCTAssertEqual(pick(dusk, ["laptop"], words).first, "duskword", "날씨를 모르면 비 말은 안 쓴다")
        XCTAssertEqual(pick(dusk, ["laptop"], [words[2]]), ["winterword"])
        XCTAssertEqual(pick(dusk, ["laptop"], [w("dawnword", times: [.dawn], subjects: []).asMoment]), [],
                       "때의 말도 시간대는 풀지 않는다")
    }

    func testMomentFallbackNeverUsesSubjectWords() {
        XCTAssertEqual(pick(dusk, ["laptop"], [w("moonhalo", times: [.dusk], subjects: ["moon"])]), [],
                       "대상을 말하는 단어는 대상이 찍혔을 때만")
    }

    /// 실제 단어 목록으로 — 사진에서 아무것도 못 알아봐도 어느 시각·계절·날씨든 단어가 붙는다.
    func testBundledWordsAlwaysGiveAWord() async throws {
        let words = await BundledWordSource().words()
        XCTAssertFalse(words.isEmpty)
        let weathers: [Weather?] = [nil] + Weather.allCases
        for hour in 0..<24 {
            for month in [1, 4, 7, 10] {
                var c = DateComponents(); c.year = 2026; c.month = month; c.day = 15; c.hour = hour
                let date = utc.date(from: c)!
                for weather in weathers {
                    let ctx = PhotoContext(date: date, weather: weather, calendar: utc)
                    let word = WordPicker.photoWord(for: ctx, labels: [], in: words, excluding: [], seed: "\(hour)-\(month)")
                    XCTAssertNotNil(word, "\(hour)시 \(month)월 \(weather.map(\.rawValue) ?? "날씨 모름")에 단어가 없다")
                    if let word { XCTAssertTrue(words.first { $0.id == word.wordID }?.moment == true, word.word) }
                }
            }
        }
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

    func testKnownWeatherNeverGetsOtherWeatherWords() {
        let snowy = PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), weather: .snow, calendar: utc)
        XCTAssertEqual(pick(snowy, ["snow"], [w("snowword", weathers: [.snow], subjects: ["snow"])]), ["snowword"])

        let words = [w("p", weathers: [.rain], seasons: [.winter]), w("q", weathers: [.fog], seasons: [.summer])]
        XCTAssertEqual(pick(snowy, ["sky"], words), [], "다른 날씨 말은 끝까지 안 쓴다")

        let clear = PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), weather: .clear, calendar: utc)
        XCTAssertEqual(pick(clear, ["sky"], [w("a", weathers: [.clear]), w("r", weathers: [.rain])], recent: ["a"]), ["a"],
                       "최근 반복을 허용할지언정 비 말은 안 쓴다")

        XCTAssertEqual(pick(clear, ["sky"], [w("s", seasons: [.summer])]), ["s"], "계절 완화도 여전히 동작한다")
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

private extension WordEntry {
    var asMoment: WordEntry { var e = self; e.moment = true; return e }
}
