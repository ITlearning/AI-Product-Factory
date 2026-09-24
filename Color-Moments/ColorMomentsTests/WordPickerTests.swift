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
