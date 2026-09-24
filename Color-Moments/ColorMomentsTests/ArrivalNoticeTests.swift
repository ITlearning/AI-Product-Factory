import XCTest
@testable import ColorMoments

final class ArrivalNoticeTests: XCTestCase {

    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = mi
        return calendar.date(from: c)!
    }

    private func plan(dayKey: String = "2026-09-24", hasPebble: Bool = true, closed: Bool = false,
                      gifted: Bool = false, now: Date? = nil) -> ArrivalNotice.Request? {
        ArrivalNotice.plan(dayKey: dayKey, hasPebble: hasPebble, closed: closed, gifted: gifted,
                          now: now ?? date(2026, 9, 24, 12, 0), calendar: calendar)
    }

    func testNoPhotosYieldsNil() {
        XCTAssertNil(plan(hasPebble: false))
    }

    func testClosedDayYieldsNil() {
        XCTAssertNil(plan(closed: true))
    }

    func testGiftedDayYieldsNil() {
        XCTAssertNil(plan(gifted: true))
    }

    func testFireDateIsEightAMOfNextDay() {
        let request = plan(dayKey: "2026-09-24", now: date(2026, 9, 24, 12, 0))
        XCTAssertEqual(request?.fireDate, date(2026, 9, 25, 8, 0))
    }

    func testAfterEightAMYieldsNil() {
        let request = plan(dayKey: "2026-09-24", now: date(2026, 9, 25, 9, 0))
        XCTAssertNil(request)
    }

    // 이름은 색으로 정해진다(「노을」=빨강) — 알림이 증정보다 먼저 색을 드러내면 안 된다.
    func testBodyNeverCarriesPebbleName() {
        XCTAssertEqual(plan()?.body, "어제의 조약돌이 도착했어요.")
    }

    func testEarlyMorningStillYesterdaysDayKeyFiresThatSameMorning() {
        // 새벽 2시 — 4시 경계라 dayKey 는 아직 어제. 그날 아침 8시(=dayKey 다음 날 08시)는 아직 안 지났다.
        let request = plan(dayKey: "2026-09-23", now: date(2026, 9, 24, 2, 0))
        XCTAssertEqual(request?.fireDate, date(2026, 9, 24, 8, 0))
    }

    func testIdentifierIncludesDayKey() {
        let request = plan(dayKey: "2026-09-24")
        XCTAssertEqual(request?.id, "arrival-2026-09-24")
    }

    // MARK: - targets

    func testTargetsBeforeDayBoundaryOnlyStillOpenDay() {
        XCTAssertEqual(ArrivalNotice.targets(now: date(2026, 9, 25, 3, 59), calendar: calendar), ["2026-09-24"])
    }

    func testTargetsAfterBoundaryKeepYesterdayUntilEight() {
        XCTAssertEqual(ArrivalNotice.targets(now: date(2026, 9, 25, 4, 1), calendar: calendar),
                       ["2026-09-24", "2026-09-25"])
        XCTAssertEqual(ArrivalNotice.targets(now: date(2026, 9, 25, 7, 59), calendar: calendar),
                       ["2026-09-24", "2026-09-25"])
    }

    func testTargetsAfterEightOnlyToday() {
        XCTAssertEqual(ArrivalNotice.targets(now: date(2026, 9, 25, 8, 1), calendar: calendar), ["2026-09-25"])
        XCTAssertEqual(ArrivalNotice.targets(now: date(2026, 9, 25, 23, 0), calendar: calendar), ["2026-09-25"])
    }

    func testTargetsCrossMonth() {
        XCTAssertEqual(ArrivalNotice.targets(now: date(2026, 10, 1, 5, 0), calendar: calendar),
                       ["2026-09-30", "2026-10-01"])
    }

    // MARK: - 권한 묻기

    func testAsksOnlyWhenNoNextGiftIsWaiting() {
        XCTAssertTrue(ArrivalNotice.shouldAsk(didAsk: false, nextGift: nil))
        XCTAssertFalse(ArrivalNotice.shouldAsk(didAsk: false, nextGift: "2026-09-24"))
        XCTAssertFalse(ArrivalNotice.shouldAsk(didAsk: true, nextGift: nil))
    }
}
