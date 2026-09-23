import XCTest
@testable import ColorMoments

final class WordPickerTests: XCTestCase {

    private func w(_ id: String, times: [TimeBand] = [], weathers: [Weather] = [], seasons: [Season] = []) -> WordEntry {
        WordEntry(id: id, word: id, meaning: "뜻 \(id)", times: times, weathers: weathers, seasons: seasons)
    }

    private let duskCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }()

    private lazy var dusk = PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), calendar: duskCalendar)
    // 1970-01-01 18:00 UTC → dusk, winter

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
                       "날씨 단어뿐이면 최종 폴백으로 나온다 — dusk 픽스처엔 날씨가 없어 매칭 자체가 안 된다")

        let snowDusk = PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), weather: .snow, calendar: duskCalendar)
        let weatherWrong = [w("p", times: [.dusk], weathers: [.rain], seasons: [.winter]),
                            w("q", times: [.dusk], weathers: [.fog], seasons: [.summer])]
        XCTAssertEqual(WordPicker.candidates(for: snowDusk, in: weatherWrong, excluding: [], seed: "s").map(\.id), ["p"],
                       "날씨를 계절보다 먼저 풀어야 한다 — 눈 오는 사진엔 계절 안 맞는 겨울 말이 여름 말보다 낫다")

        let seasonWrong = [w("y", times: [.dusk], seasons: [.summer]), w("z", times: [.dawn], seasons: [.winter])]
        XCTAssertEqual(WordPicker.candidates(for: dusk, in: seasonWrong, excluding: [], seed: "s").map(\.id), ["y"],
                       "계절을 시간대보다 먼저 풀어야 한다 — 해질녘 사진에 새벽 말이 붙으면 안 된다")
    }

    func testWeatherlessPhotoNeverGetsWeatherWordEvenWhenRecentExcludesEverythingElse() {
        let words = [w("plain", times: [.dusk]), w("rainy", weathers: [.rain])]
        XCTAssertEqual(WordPicker.candidates(for: dusk, in: words, excluding: ["plain"], seed: "s").map(\.id), ["plain"],
                       "recent 로 막힌 날씨 없는 단어라도, recent 를 해제해서라도 날씨 단어보다 먼저 나온다")
    }

    func testWeatherWordOnlyAppearsAsFinalFallbackWhenNothingElseExists() {
        let words = [w("rainy", weathers: [.rain])]
        XCTAssertEqual(WordPicker.candidates(for: dusk, in: words, excluding: [], seed: "s").map(\.id), ["rainy"],
                       "날씨 없는 사진에 날씨 단어뿐이면, 최종 폴백에서만 나온다")
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
