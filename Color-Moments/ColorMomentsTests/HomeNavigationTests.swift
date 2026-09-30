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

@MainActor
final class HomeBackdropBlendTests: XCTestCase {
    func testTopOfListShowsFirstDayAlone() {
        let b = HomeBackdropBlend()
        b.setOrder(["d3", "d2", "d1"])
        b.setReference(400)
        b.report("d3", top: 520)
        b.report("d2", top: 900)
        XCTAssertEqual(b.from, "d3")
        XCTAssertNil(b.to)
        XCTAssertEqual(b.t, 0)
    }

    func testBlendsByDistanceOfNextRowToReference() {
        let b = HomeBackdropBlend()
        b.setOrder(["d3", "d2", "d1"])
        b.setReference(400)
        b.report("d3", top: 300)
        b.report("d2", top: 700)
        XCTAssertEqual(b.from, "d3")
        XCTAssertEqual(b.to, "d2")
        // 다음 하루가 기준선까지 1/4 왔다 — smoothstep(0.25)
        XCTAssertEqual(b.t, 0.15625, accuracy: 0.005)

        b.report("d2", top: 500)
        XCTAssertEqual(b.t, 0.5, accuracy: 0.005)
    }

    func testHandsOverWhenNextRowCrossesReference() {
        let b = HomeBackdropBlend()
        b.setOrder(["d3", "d2", "d1"])
        b.setReference(400)
        b.report("d3", top: -100)
        b.report("d2", top: 390)
        b.report("d1", top: 800)
        XCTAssertEqual(b.from, "d2")
        XCTAssertEqual(b.to, "d1")
        XCTAssertLessThan(b.t, 0.05)
    }

    func testForgottenRowsDropOut() {
        let b = HomeBackdropBlend()
        b.setOrder(["d3", "d2"])
        b.setReference(400)
        b.report("d3", top: 100)
        b.report("d2", top: 300)
        XCTAssertEqual(b.from, "d2")
        b.forget("d2")
        b.report("d3", top: 120)
        XCTAssertEqual(b.from, "d3")
    }
}
