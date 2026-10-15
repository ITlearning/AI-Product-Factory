import XCTest
@testable import ColorMoments

final class AmbientNowTests: XCTestCase {

    private let words = BundledWordSource.cached

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        PhotoContext.korea.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// 한 해를 철마다 하루씩, 하루를 시간마다 — 날씨는 모름·맑음·비·가는 비·눈·안개.
    private var grid: [(Date, PlaceWeather?)] {
        let weathers: [PlaceWeather?] = [nil, .init(condition: "clear", celsius: 18), .init(condition: "rain", celsius: 14),
                                         .init(condition: "drizzle", celsius: 12), .init(condition: "snow", celsius: -2),
                                         .init(condition: "foggy", celsius: 9)]
        var out: [(Date, PlaceWeather?)] = []
        for m in [1, 4, 7, 10] {
            for h in 0..<24 { for w in weathers { out.append((date(2026, m, 15, h, 20), w)) } }
        }
        return out
    }

    func testOnlyMomentOrAmbientWordsEverComeOut() {
        var seen = 0
        for (d, w) in grid {
            guard let word = AmbientNow.word(at: d, context: AmbientNow.context(at: d, weather: w), in: words) else { continue }
            seen += 1
            XCTAssertTrue(word.moment || word.ambient, "\(word.word) 은 장면 말 — 위젯·지금의 말 후보가 아니다")
            XCTAssertFalse(word.rest)
        }
        XCTAssertGreaterThan(seen, grid.count / 2, "거의 늘 말 하나는 나와야 한다")
    }

    func testSceneWordsAreNotCandidates() throws {
        for w in words where !w.moment && !w.ambient {
            XCTAssertFalse(AmbientNow.isCandidate(w), w.word)
        }
        XCTAssertFalse(words.filter { !$0.moment && !$0.ambient }.isEmpty)
    }

    func testSameInputSameWord() {
        for (d, w) in grid.prefix(200) {
            let a = AmbientNow.word(at: d, context: AmbientNow.context(at: d, weather: w), in: words)
            let b = AmbientNow.word(at: d, context: AmbientNow.context(at: d, weather: w), in: words.reversed())
            XCTAssertEqual(a?.id, b?.id, "같은 날·같은 시각이면 목록 순서와 상관없이 같은 말")
        }
    }

    func testSameHourSameWordAcrossMinutes() {
        let a = date(2026, 10, 15, 18, 1), b = date(2026, 10, 15, 18, 2)
        XCTAssertEqual(AmbientNow.word(at: a, context: AmbientNow.context(at: a), in: words)?.id,
                       AmbientNow.word(at: b, context: AmbientNow.context(at: b), in: words)?.id)
    }

    func testNoLocationMeansSeoul() {
        for (d, w) in grid.prefix(300) {
            let none = AmbientNow.word(at: d, context: AmbientNow.context(at: d, weather: w), in: words)
            let seoul = AmbientNow.word(at: d, context: AmbientNow.context(at: d, weather: w, coordinate: Celestial.seoul), in: words)
            XCTAssertEqual(none?.id, seoul?.id)
        }
    }

    func testNoWeatherGivesComputedWordOnly() {
        var seen = 0
        for (d, w) in grid where w == nil {
            guard let word = AmbientNow.word(at: d, context: AmbientNow.context(at: d), in: words) else { continue }
            seen += 1
            XCTAssertTrue(word.weathers.isEmpty && word.conditions.isEmpty && word.needs.isEmpty, "\(word.word) — 날씨를 모르는데 날씨 말")
            XCTAssertNil(word.minCelsius, word.word)
            XCTAssertNil(word.maxCelsius, word.word)
        }
        XCTAssertGreaterThan(seen, 48)
    }

    func testRainComesBeforeTimeWords() throws {
        let d = date(2026, 10, 15, 18, 30)
        let word = try XCTUnwrap(AmbientNow.word(at: d, context: AmbientNow.context(at: d, weather: .init(condition: "rain", celsius: 14)),
                                                 in: words))
        XCTAssertEqual(AmbientNow.rank(word), 0, "\(word.word) — 비가 오면 비 말이 먼저")
        XCTAssertTrue(word.weathers.contains(.rain) || !word.conditions.isEmpty, word.word)
    }

    func testSceneKindFollowsConditions() throws {
        func kind(_ id: String) throws -> SceneKind { SceneKind.of(try XCTUnwrap(words.first { $0.id == id }, id)) }
        XCTAssertEqual(try kind("neungae"), .drizzle)
        XCTAssertEqual(try kind("jakdalbi"), .rain)
        XCTAssertEqual(try kind("nunbora"), .snow)
        XCTAssertEqual(try kind("haegeoreum"), .dusk)
        XCTAssertEqual(try kind("saebyeoknyeok"), .dawn)
        XCTAssertEqual(try kind("ondal"), .moon)
        XCTAssertEqual(try kind("gaeulbyeot"), .sun)
        XCTAssertEqual(try kind("kkotsaemchuwi"), .frost)
    }
}
