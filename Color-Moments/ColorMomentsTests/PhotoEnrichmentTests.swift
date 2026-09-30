import XCTest
@testable import ColorMoments

final class PhotoEnrichmentTests: XCTestCase {

    private let known = [
        "clear", "mostlyClear", "hot", "partlyCloudy", "mostlyCloudy", "cloudy", "drizzle",
        "rain", "heavyRain", "sunShowers", "freezingRain", "freezingDrizzle",
        "snow", "flurries", "heavySnow", "sleet", "sunFlurries", "wintryMix", "blowingSnow", "blizzard",
        "foggy", "haze", "smoky", "windy", "breezy",
        "thunderstorms", "isolatedThunderstorms", "scatteredThunderstorms", "strongStorms",
    ]

    func testEveryLabelledConditionHasASymbolDayAndNight() {
        for c in known {
            XCTAssertNotNil(PhotoEnrichment.label(c), c)
            XCTAssertNotNil(PhotoEnrichment.symbol(c, night: false), c)
            XCTAssertNotNil(PhotoEnrichment.symbol(c, night: true), c)
        }
    }

    func testUnknownConditionShowsNeitherLabelNorSymbol() {
        XCTAssertNil(PhotoEnrichment.label("hail"))
        XCTAssertNil(PhotoEnrichment.symbol("hail", night: false))
    }

    func testClearSkiesTurnToMoonAtNight() {
        XCTAssertEqual(PhotoEnrichment.symbol("clear", night: false), "sun.max")
        XCTAssertEqual(PhotoEnrichment.symbol("clear", night: true), "moon.stars")
        XCTAssertEqual(PhotoEnrichment.symbol("partlyCloudy", night: true), "cloud.moon")
        XCTAssertEqual(PhotoEnrichment.symbol("cloudy", night: true), "cloud")
    }

    func testNightIsSevenPMToSixAM() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        func at(_ h: Int, _ m: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: h, minute: m))! }
        XCTAssertTrue(PhotoEnrichment.isNight(at(0, 34), calendar: cal))
        XCTAssertTrue(PhotoEnrichment.isNight(at(5, 59), calendar: cal))
        XCTAssertFalse(PhotoEnrichment.isNight(at(6, 0), calendar: cal))
        XCTAssertFalse(PhotoEnrichment.isNight(at(18, 59), calendar: cal))
        XCTAssertTrue(PhotoEnrichment.isNight(at(19, 0), calendar: cal))
    }

    func testPartOfDayFollowsTheFourAMDayBoundary() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        func part(_ h: Int, _ m: Int) -> String {
            PhotoEnrichment.partOfDay(cal.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: h, minute: m))!,
                                      calendar: cal)
        }
        XCTAssertEqual(part(0, 34), "밤")
        XCTAssertEqual(part(3, 59), "밤")
        XCTAssertEqual(part(4, 0), "새벽")
        XCTAssertEqual(part(6, 59), "새벽")
        XCTAssertEqual(part(7, 0), "아침")
        XCTAssertEqual(part(10, 59), "아침")
        XCTAssertEqual(part(11, 0), "낮")
        XCTAssertEqual(part(16, 59), "낮")
        XCTAssertEqual(part(17, 0), "저녁")
        XCTAssertEqual(part(19, 59), "저녁")
        XCTAssertEqual(part(20, 0), "밤")
    }
}
