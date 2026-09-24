import XCTest
@testable import ColorMoments

final class EveningReminderTests: XCTestCase {

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

    func testNoPhotosYieldsNil() {
        let plan = EveningReminder.plan(todayKey: "2026-09-24", momentCount: 0, closed: false,
                                        now: date(2026, 9, 24, 12, 0), calendar: calendar)
        XCTAssertNil(plan)
    }

    func testClosedDayYieldsNil() {
        let plan = EveningReminder.plan(todayKey: "2026-09-24", momentCount: 3, closed: true,
                                        now: date(2026, 9, 24, 12, 0), calendar: calendar)
        XCTAssertNil(plan)
    }

    func testAfterTenPMYieldsNil() {
        let plan = EveningReminder.plan(todayKey: "2026-09-24", momentCount: 3, closed: false,
                                        now: date(2026, 9, 24, 22, 30), calendar: calendar)
        XCTAssertNil(plan)
    }

    func testExactlyTenPMYieldsNil() {
        let plan = EveningReminder.plan(todayKey: "2026-09-24", momentCount: 3, closed: false,
                                        now: date(2026, 9, 24, 22, 0), calendar: calendar)
        XCTAssertNil(plan, "정확히 22시면 이미 지난 것으로 본다")
    }

    func testOneMomentSaysHanSungan() {
        let plan = EveningReminder.plan(todayKey: "2026-09-24", momentCount: 1, closed: false,
                                        now: date(2026, 9, 24, 12, 0), calendar: calendar)
        XCTAssertEqual(plan?.body, "오늘 한 순간이 담겼어요. 지금 조약돌로 열어 볼 수 있어요.")
    }

    func testThreeMomentsSaysSeSungan() {
        let plan = EveningReminder.plan(todayKey: "2026-09-24", momentCount: 3, closed: false,
                                        now: date(2026, 9, 24, 12, 0), calendar: calendar)
        XCTAssertEqual(plan?.body, "오늘 세 순간이 담겼어요. 지금 조약돌로 열어 볼 수 있어요.")
    }

    func testTenMomentsUsesLastCounter() {
        let plan = EveningReminder.plan(todayKey: "2026-09-24", momentCount: 10, closed: false,
                                        now: date(2026, 9, 24, 12, 0), calendar: calendar)
        XCTAssertEqual(plan?.body, "오늘 열 순간이 담겼어요. 지금 조약돌로 열어 볼 수 있어요.")
    }

    func testTwelveMomentsSaysDigitGae() {
        let plan = EveningReminder.plan(todayKey: "2026-09-24", momentCount: 12, closed: false,
                                        now: date(2026, 9, 24, 12, 0), calendar: calendar)
        XCTAssertEqual(plan?.body, "오늘 12개의 순간이 담겼어요. 지금 조약돌로 열어 볼 수 있어요.")
    }

    func testEarlyMorningStillYesterdaysDayKeyIsPastTenPMAlready() {
        // 새벽 2시 — 4시 경계라 dayKey 는 아직 어제. 어제의 22시는 이미 지났다.
        let plan = EveningReminder.plan(todayKey: "2026-09-23", momentCount: 2, closed: false,
                                        now: date(2026, 9, 24, 2, 0), calendar: calendar)
        XCTAssertNil(plan)
    }

    func testIdentifierIncludesDayKey() {
        let plan = EveningReminder.plan(todayKey: "2026-09-24", momentCount: 1, closed: false,
                                        now: date(2026, 9, 24, 12, 0), calendar: calendar)
        XCTAssertEqual(plan?.id, "evening-2026-09-24")
    }

    func testFireDateIsTenPMOfDayKey() {
        let plan = EveningReminder.plan(todayKey: "2026-09-24", momentCount: 1, closed: false,
                                        now: date(2026, 9, 24, 12, 0), calendar: calendar)
        XCTAssertEqual(plan?.fireDate, date(2026, 9, 24, 22, 0))
    }
}
