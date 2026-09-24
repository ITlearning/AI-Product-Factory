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
