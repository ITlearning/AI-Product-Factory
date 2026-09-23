import XCTest
@testable import ColorMoments

final class GiftScheduleTests: XCTestCase {

    func testTodayIsNeverGifted() {
        XCTAssertNil(GiftSchedule.pending(dayKeys: ["2026-09-22"], today: "2026-09-22",
                                          isGifted: { _ in false }))
    }

    func testFirstRunGiftsTheMostRecentFinishedDay() {
        XCTAssertEqual(GiftSchedule.pending(dayKeys: ["2026-09-22", "2026-09-21"], today: "2026-09-22",
                                            isGifted: { _ in false }),
                       "2026-09-21")
    }

    func testAlreadyGiftedDayDoesNotComeBack() {
        XCTAssertNil(GiftSchedule.pending(dayKeys: ["2026-09-22", "2026-09-21"], today: "2026-09-22",
                                          isGifted: { $0 <= "2026-09-21" }))
    }

    func testBacklogGiftsOnlyTheMostRecent() {
        let keys = ["2026-09-21", "2026-09-20", "2026-09-19"]
        XCTAssertEqual(GiftSchedule.pending(dayKeys: keys, today: "2026-09-22", isGifted: { _ in false }),
                       "2026-09-21")
    }

    func testOlderBacklogNeverComesBackAfterGifting() {
        let keys = ["2026-09-21", "2026-09-20", "2026-09-19"]
        let first = GiftSchedule.pending(dayKeys: keys, today: "2026-09-22", isGifted: { _ in false })
        XCTAssertEqual(first, "2026-09-21")

        XCTAssertNil(GiftSchedule.pending(dayKeys: keys, today: "2026-09-22",
                                          isGifted: { k in first.map { k <= $0 } ?? false }))
    }

    func testEmptyDaysAreSkipped() {

        XCTAssertEqual(GiftSchedule.pending(dayKeys: ["2026-09-20"], today: "2026-09-22",
                                            isGifted: { _ in false }),
                       "2026-09-20")
    }

    func testNothingRecordedYet() {
        XCTAssertNil(GiftSchedule.pending(dayKeys: [], today: "2026-09-22", isGifted: { _ in false }))
    }

    func testDayWithoutSealedMomentsIsSkippedInFavorOfTheNextCandidate() {
        let keys = ["2026-09-21", "2026-09-20"]
        // 뒤에 isFinished 라는 또 다른 트레일링 클로저 자리가 있어 단일 트레일링 클로저는
        // (후방 매칭 규칙 때문에) hasSealedMoments 가 아니라 isFinished 로 가 버린다 — 라벨을 명시한다.
        let result = GiftSchedule.pending(dayKeys: keys, today: "2026-09-22", isGifted: { _ in false },
                                          hasSealedMoments: { $0 != "2026-09-21" })
        XCTAssertEqual(result, "2026-09-20", "조약돌 없던 날은 건너뛰고 다음 후보로 넘어간다")
    }

    func testAllCandidatesWithoutSealedMomentsYieldsNil() {
        let keys = ["2026-09-21", "2026-09-20"]
        XCTAssertNil(GiftSchedule.pending(dayKeys: keys, today: "2026-09-22", isGifted: { _ in false },
                                          hasSealedMoments: { _ in false }))
    }

    func testClosedTodayCanBePending() {
        XCTAssertEqual(GiftSchedule.pending(dayKeys: ["2026-09-22"], today: "2026-09-22",
                                            isGifted: { _ in false },
                                            isFinished: { _ in true }),
                       "2026-09-22", "오늘이어도 마무리(isFinished)했으면 증정 대상이 된다")
    }

    func testUnclosedTodayStillNeverGiftedWithIsFinished() {
        XCTAssertNil(GiftSchedule.pending(dayKeys: ["2026-09-22"], today: "2026-09-22",
                                          isGifted: { _ in false },
                                          isFinished: { _ in false }))
    }

    func testYesterdayUngiftedComesBeforeTodayEvenWhenTodayIsFinished() {
        let keys = ["2026-09-22", "2026-09-21"]
        XCTAssertEqual(GiftSchedule.pending(dayKeys: keys, today: "2026-09-22",
                                            isGifted: { _ in false },
                                            isFinished: { _ in true }),
                       "2026-09-21", "어제가 아직 안 받았으면 마무리한 오늘보다 어제가 먼저다")
    }

    func testTodayComesAfterYesterdayIsGifted() {
        let keys = ["2026-09-22", "2026-09-21"]
        XCTAssertEqual(GiftSchedule.pending(dayKeys: keys, today: "2026-09-22",
                                            isGifted: { $0 == "2026-09-21" },
                                            isFinished: { _ in true }),
                       "2026-09-22", "어제를 이미 받았으면 다음은 마무리한 오늘이다")
    }

    func testMostRecentNaturalDayAlreadyGiftedYieldsNilEvenWithOlderUngiftedDays() {
        let keys = ["2026-09-21", "2026-09-20"]
        XCTAssertNil(GiftSchedule.pending(dayKeys: keys, today: "2026-09-22",
                                          isGifted: { $0 == "2026-09-21" }),
                    "밀린 날 중 가장 최근이 이미 받은 날이면 더 오래된 날까지 뒤늦게 주지 않는다")
    }

    func testGiftLogPersists() throws {
        let suite = "GiftLogTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        GiftLog(defaults: defaults).markGifted("2026-09-21")
        XCTAssertTrue(GiftLog(defaults: defaults).isGifted("2026-09-21"))

        GiftLog(defaults: defaults).reset()
        XCTAssertFalse(GiftLog(defaults: defaults).isGifted("2026-09-21"))
    }

    func testGiftLogHonorsLegacySingleKey() throws {
        let suite = "GiftLogLegacy-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("2026-09-21", forKey: "lastGiftedDayKey")

        let gifts = GiftLog(defaults: defaults)
        XCTAssertTrue(gifts.isGifted("2026-09-20"), "옛 단일 키 이하 날짜는 받은 것으로 본다")
        XCTAssertTrue(gifts.isGifted("2026-09-21"))
        XCTAssertFalse(gifts.isGifted("2026-09-22"))
    }

    func testGiftLogSetPersistsAcrossInstances() throws {
        let suite = "GiftLogSet-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        GiftLog(defaults: defaults).markGifted("2026-09-20")
        GiftLog(defaults: defaults).markGifted("2026-09-21")

        let reopened = GiftLog(defaults: defaults)
        XCTAssertTrue(reopened.isGifted("2026-09-20"))
        XCTAssertTrue(reopened.isGifted("2026-09-21"))
        XCTAssertFalse(reopened.isGifted("2026-09-22"))
    }

    func testDuplicateMarkGiftedIsIgnored() throws {
        let suite = "GiftLogDup-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let gifts = GiftLog(defaults: defaults)
        gifts.markGifted("2026-09-21")
        gifts.markGifted("2026-09-21")
        XCTAssertEqual(gifts.giftedDayKeys, ["2026-09-21"])
    }

    func testGiftLogNotifiesLocalOnlyAndPersists() {
        let d = UserDefaults(suiteName: UUID().uuidString)!
        let log = GiftLog(defaults: d)
        var got: [String] = []
        log.onLocalChange = { got.append($0) }
        log.markGifted("2026-09-21")
        log.markGifted("2026-09-21")
        log.applyRemote(gifted: "2026-09-22")
        XCTAssertEqual(got, ["2026-09-21"], "다른 기기에서 온 증정은 되돌려 올리지 않는다")
        let again = GiftLog(defaults: d)
        XCTAssertTrue(again.isGifted("2026-09-21"))
        XCTAssertTrue(again.isGifted("2026-09-22"))
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
        let closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        store = DayStore(fileURL: tempFile, closures: closures)
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
