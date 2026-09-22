import XCTest
@testable import ColorMoments

/// 「하루가 끝나면 딱 한 번」 규칙.
///
/// 눈으로 확인하려면 날짜를 넘겨가며 며칠을 써야 하는 규칙이라 여기서 못 박는다.
final class GiftScheduleTests: XCTestCase {

    /// 오늘은 아직 안 끝났다. 증정하면 「자정에 열린다」가 깨진다.
    func testTodayIsNeverGifted() {
        XCTAssertNil(GiftSchedule.pending(dayKeys: ["2026-09-22"],
                                          lastGifted: nil,
                                          today: "2026-09-22"))
    }

    /// 어제 것은 첫 실행에 바로 건넨다.
    func testFirstRunGiftsTheMostRecentFinishedDay() {
        XCTAssertEqual(GiftSchedule.pending(dayKeys: ["2026-09-22", "2026-09-21"],
                                            lastGifted: nil,
                                            today: "2026-09-22"),
                       "2026-09-21")
    }

    /// 같은 하루를 두 번 주지 않는다.
    func testAlreadyGiftedDayDoesNotComeBack() {
        XCTAssertNil(GiftSchedule.pending(dayKeys: ["2026-09-22", "2026-09-21"],
                                          lastGifted: "2026-09-21",
                                          today: "2026-09-22"))
    }

    /// **밀린 날이 여러 개면 가장 최근 하나만.**
    /// 사흘 만에 열었다고 세 번 연달아 보여주면 보상이 아니라 밀린 숙제가 된다.
    func testBacklogGiftsOnlyTheMostRecent() {
        let keys = ["2026-09-21", "2026-09-20", "2026-09-19"]
        XCTAssertEqual(GiftSchedule.pending(dayKeys: keys, lastGifted: nil, today: "2026-09-22"),
                       "2026-09-21")
    }

    /// 그리고 나머지는 **조용히 쌓인다** — 커서가 최근 날로 옮겨가므로 다시 오지 않는다.
    func testOlderBacklogNeverComesBackAfterGifting() {
        let keys = ["2026-09-21", "2026-09-20", "2026-09-19"]
        let first = GiftSchedule.pending(dayKeys: keys, lastGifted: nil, today: "2026-09-22")
        XCTAssertEqual(first, "2026-09-21")
        // 09-21 을 건넨 뒤: 20·19 는 목록에만 남고 증정되지 않는다.
        XCTAssertNil(GiftSchedule.pending(dayKeys: keys, lastGifted: first, today: "2026-09-22"))
    }

    /// 안 담은 날은 조약돌이 없다. 구멍이 아니라 그냥 없는 것이므로 건너뛴다.
    func testEmptyDaysAreSkipped() {
        // 09-20 만 기록이 있다 — 21 은 아예 목록에 없다.
        XCTAssertEqual(GiftSchedule.pending(dayKeys: ["2026-09-20"],
                                            lastGifted: nil,
                                            today: "2026-09-22"),
                       "2026-09-20")
    }

    func testNothingRecordedYet() {
        XCTAssertNil(GiftSchedule.pending(dayKeys: [], lastGifted: nil, today: "2026-09-22"))
    }

    /// 이력은 앱을 껐다 켜도 남아야 한다.
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

/// 증정 장면의 첫 줄. 「오늘」이 아닌 하루가 건네질 수 있으므로 말이 틀리면 안 된다.
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

    /// 사흘 만에 열면 사흘 전이 온다. 「어제」라고 하면 거짓말이 된다.
    func testOlderDayIsNotCalledYesterday() {
        let now = Date()
        XCTAssertEqual(BadgeCeremony.openingLine(for: moment(daysAgo: 3, now: now), now: now),
                       "그날이 담겼어요")
    }

    func testEmptyDayFallsBackToNeutralLine() {
        XCTAssertEqual(BadgeCeremony.openingLine(for: [], now: Date()), "하루가 담겼어요")
    }
}

/// 수집물 줄에 오늘이 끼면 안 된다. 색 고치기 입구가 그 줄이라, 오늘이 있으면
/// 자정 전에 오늘 색을 볼 수 있게 된다 — 「자정에 열린다」가 그 자리에서 깨진다.
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
