import XCTest
@testable import ColorMoments

final class HomeNavigationTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        return cal.date(from: c)!
    }

    func testCompactCutoffIsThirtyDaysBeforeTodaysDayKey() {
        XCTAssertEqual(HomeNavigation.compactCutoff(today: date(2026, 9, 23)), "2026-08-24")
    }

    func testCompactCutoffCrossesMonthAndYearBoundaries() {
        XCTAssertEqual(HomeNavigation.compactCutoff(today: date(2026, 1, 15)), "2025-12-16")
    }

    func testMonthsDedupesAndOrdersNewestFirst() {
        let keys = ["2026-09-23", "2026-09-01", "2026-08-15", "2026-08-02", "2026-07-01"]
        XCTAssertEqual(HomeNavigation.months(of: keys), ["2026-09", "2026-08", "2026-07"])
    }

    func testMonthsSortsEvenWhenInputIsUnordered() {
        let keys = ["2026-07-01", "2026-09-23", "2026-08-02"]
        XCTAssertEqual(HomeNavigation.months(of: keys), ["2026-09", "2026-08", "2026-07"])
    }

    func testMonthsIsEmptyForEmptyInput() {
        XCTAssertEqual(HomeNavigation.months(of: []), [])
    }

    func testMonthIndexClampsToValidRange() {
        XCTAssertEqual(HomeNavigation.monthIndex(fraction: -1, count: 5), 0)
        XCTAssertEqual(HomeNavigation.monthIndex(fraction: 2, count: 5), 4)
    }

    func testMonthIndexMapsFractionAcrossCount() {
        XCTAssertEqual(HomeNavigation.monthIndex(fraction: 0, count: 5), 0)
        XCTAssertEqual(HomeNavigation.monthIndex(fraction: 0.5, count: 5), 2)
        XCTAssertEqual(HomeNavigation.monthIndex(fraction: 0.999, count: 5), 4)
    }

    func testMonthIndexIsZeroForEmptyCount() {
        XCTAssertEqual(HomeNavigation.monthIndex(fraction: 0.5, count: 0), 0)
    }
}
