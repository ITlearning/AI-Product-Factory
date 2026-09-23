import XCTest
@testable import ColorMoments

final class LibrarySectionsTests: XCTestCase {

    private func d(_ y: Int, _ mo: Int, _ day: Int, _ h: Int, _ mi: Int = 0) -> Date {
        var c = DateComponents(); c.year = y; c.month = mo; c.day = day; c.hour = h; c.minute = mi
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        return cal.date(from: c)!
    }

    func testGroupsByMongdolDayBoundaryNewestFirst() {
        let dates: [Date?] = [d(2026, 9, 23, 2, 0), d(2026, 9, 22, 18, 0), d(2026, 9, 22, 5, 0), d(2026, 9, 20, 12, 0)]
        let s = LibrarySections.make(dates: dates)
        XCTAssertEqual(s.map(\.dayKey), ["2026-09-22", "2026-09-20"], "새벽 2시는 전날, 빈 날(21일)은 없다")
        XCTAssertEqual(s[0].indices, [0, 1, 2])
        XCTAssertEqual(s[1].indices, [3])
    }

    func testMissingDateFallsIntoNow() {
        let now = d(2026, 9, 23, 12, 0)
        let s = LibrarySections.make(dates: [nil, d(2026, 9, 22, 12, 0)], now: now)
        XCTAssertEqual(s.map(\.dayKey), ["2026-09-23", "2026-09-22"])
    }

    func testEmpty() { XCTAssertEqual(LibrarySections.make(dates: []), []) }

    func testTitle() { XCTAssertEqual(LibrarySections.title("2026-09-22"), "9월 22일 (화)") }
}
