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
