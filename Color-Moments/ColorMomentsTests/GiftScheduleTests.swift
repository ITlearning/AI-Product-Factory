import XCTest
@testable import ColorMoments

final class GiftScheduleTests: XCTestCase {

    func testTodayIsNeverGifted() {
        XCTAssertNil(GiftSchedule.pending(dayKeys: ["2026-09-22"],
                                          lastGifted: nil,
                                          today: "2026-09-22"))
    }

    func testFirstRunGiftsTheMostRecentFinishedDay() {
        XCTAssertEqual(GiftSchedule.pending(dayKeys: ["2026-09-22", "2026-09-21"],
                                            lastGifted: nil,
                                            today: "2026-09-22"),
                       "2026-09-21")
    }

    func testAlreadyGiftedDayDoesNotComeBack() {
        XCTAssertNil(GiftSchedule.pending(dayKeys: ["2026-09-22", "2026-09-21"],
                                          lastGifted: "2026-09-21",
                                          today: "2026-09-22"))
    }

    func testBacklogGiftsOnlyTheMostRecent() {
        let keys = ["2026-09-21", "2026-09-20", "2026-09-19"]
        XCTAssertEqual(GiftSchedule.pending(dayKeys: keys, lastGifted: nil, today: "2026-09-22"),
                       "2026-09-21")
    }

    func testOlderBacklogNeverComesBackAfterGifting() {
        let keys = ["2026-09-21", "2026-09-20", "2026-09-19"]
        let first = GiftSchedule.pending(dayKeys: keys, lastGifted: nil, today: "2026-09-22")
        XCTAssertEqual(first, "2026-09-21")

        XCTAssertNil(GiftSchedule.pending(dayKeys: keys, lastGifted: first, today: "2026-09-22"))
    }

    func testEmptyDaysAreSkipped() {

        XCTAssertEqual(GiftSchedule.pending(dayKeys: ["2026-09-20"],
                                            lastGifted: nil,
                                            today: "2026-09-22"),
                       "2026-09-20")
    }

    func testNothingRecordedYet() {
        XCTAssertNil(GiftSchedule.pending(dayKeys: [], lastGifted: nil, today: "2026-09-22"))
    }

    func testGiftLogPersists() throws {
        let suite = "GiftLogTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        GiftLog(defaults: defaults).markGifted("2026-09-21")
        XCTAssertEqual(GiftLog(defaults: defaults).lastGiftedDayKey, "2026-09-21")

        GiftLog(defaults: defaults).reset()
        XCTAssertNil(GiftLog(defaults: defaults).lastGiftedDayKey)
    }
}

final class CeremonyCopyTests: XCTestCase {

    private func moment(daysAgo: Int, now: Date) -> [Moment] {
        [Moment(capturedAt: now.addingTimeInterval(Double(-86_400 * daysAgo)),
                colorHex: "#B12E12", fileName: "x.jpg", source: .app)]
    }

    func testTodayIsCalledToday() {
        let now = Date()
        XCTAssertEqual(BadgeCeremony.openingLine(for: moment(daysAgo: 0, now: now), now: now),
                       "오늘이 담겼어요")
    }

    func testYesterdayIsCalledYesterday() {
        let now = Date()
        XCTAssertEqual(BadgeCeremony.openingLine(for: moment(daysAgo: 1, now: now), now: now),
                       "어제가 담겼어요")
    }

    func testOlderDayIsNotCalledYesterday() {
        let now = Date()
        XCTAssertEqual(BadgeCeremony.openingLine(for: moment(daysAgo: 3, now: now), now: now),
                       "그날이 담겼어요")
    }

    func testEmptyDayFallsBackToNeutralLine() {
        XCTAssertEqual(BadgeCeremony.openingLine(for: [], now: Date()), "하루가 담겼어요")
    }
}

final class FinishedDayKeysTests: XCTestCase {

    private var tempFile: URL!
    private var store: DayStore!

    override func setUp() {
        super.setUp()
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("days-\(UUID().uuidString).json")
        store = DayStore(fileURL: tempFile)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFile)
        super.tearDown()
    }

    private func add(daysAgo: Int) {
        store.add(Moment(capturedAt: Date().addingTimeInterval(Double(-86_400 * daysAgo)),
                         colorHex: "#112233", fileName: "f\(daysAgo)-\(UUID().uuidString).jpg",
                         source: .app))
    }

    func testTodayIsNotInTheRow() {
        add(daysAgo: 0)
        XCTAssertEqual(store.dayKeys.count, 1, "오늘은 기록에는 있어야 한다")
        XCTAssertTrue(store.finishedDayKeys.isEmpty, "오늘이 수집물 줄에 올라왔다")
    }

    func testFinishedDaysAreInTheRowNewestFirst() {
        add(daysAgo: 0); add(daysAgo: 1); add(daysAgo: 3)
        let keys = store.finishedDayKeys
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(keys, keys.sorted(by: >), "최근 날짜부터가 아니다")
        XCTAssertFalse(keys.contains(Moment.dayKey(for: Date())))
    }
}
