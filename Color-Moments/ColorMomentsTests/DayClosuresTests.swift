import XCTest
@testable import ColorMoments

final class DayClosuresTests: XCTestCase {

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    func testPersistsAcrossInstances() {
        let d = defaults()
        DayClosures(defaults: d).close("2026-09-22", at: Date(timeIntervalSince1970: 1_000))
        let reopened = DayClosures(defaults: d)
        XCTAssertEqual(reopened.closedAt("2026-09-22"), Date(timeIntervalSince1970: 1_000))
    }

    func testSecondCloseIsIgnored() {
        let closures = DayClosures(defaults: defaults())
        closures.close("2026-09-22", at: Date(timeIntervalSince1970: 1_000))
        closures.close("2026-09-22", at: Date(timeIntervalSince1970: 9_000))
        XCTAssertEqual(closures.closedAt("2026-09-22"), Date(timeIntervalSince1970: 1_000),
                       "먼저 닫힌 시각이 유지돼야 한다 — 나중 사진이 조약돌에 섞이면 안 된다")
    }

    func testUnclosedDayHasNoClosedAt() {
        let closures = DayClosures(defaults: defaults())
        XCTAssertNil(closures.closedAt("2026-09-22"))
    }

    func testResetClearsAllAndPersists() {
        let d = defaults()
        let closures = DayClosures(defaults: d)
        closures.close("2026-09-22")
        closures.reset()
        XCTAssertNil(closures.closedAt("2026-09-22"))
        XCTAssertNil(DayClosures(defaults: d).closedAt("2026-09-22"))
    }
}

final class DayStoreClosureIntegrationTests: XCTestCase {

    private var tempFile: URL!
    private var closures: DayClosures!
    private var store: DayStore!

    override func setUp() {
        super.setUp()
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("days-\(UUID().uuidString).json")
        closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        store = DayStore(fileURL: tempFile, closures: closures)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFile)
        super.tearDown()
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: c)!
    }

    private func moment(_ at: Date, name: String) -> Moment {
        Moment(capturedAt: at, colorHex: "#112233", fileName: name, source: .app)
    }

    func testFinishingTodayPutsItInFinishedDayKeys() {
        let today = Moment.dayKey(for: Date())
        store.add(moment(Date(), name: "now.jpg"))
        XCTAssertFalse(store.isFinished(today))
        XCTAssertFalse(store.finishedDayKeys.contains(today))

        closures.close(today)

        XCTAssertTrue(store.isFinished(today))
        XCTAssertTrue(store.finishedDayKeys.contains(today))
    }

    func testPastDayIsAlwaysFinishedEvenWithoutClosing() {
        store.add(moment(date(2020, 1, 1, 12, 0), name: "old.jpg"))
        XCTAssertTrue(store.isFinished("2020-01-01"), "오늘보다 이전이면 닫힌 적 없어도 항상 끝난 하루")
    }

    func testPhotoTakenAfterEarlyFinishStaysOutOfThePebbleButShowsOnTimeline() {
        let closeAt = date(2026, 9, 10, 20, 0)
        closures.close("2026-09-10", at: closeAt)
        store.add(moment(date(2026, 9, 10, 19, 0), name: "before.jpg"))
        store.add(moment(date(2026, 9, 10, 21, 0), name: "after.jpg"))

        XCTAssertEqual(store.pebbleMoments(on: "2026-09-10").map(\.fileName), ["before.jpg"],
                       "마무리 뒤 찍은 사진(addedAt 없음)은 capturedAt 기준으로 걸러야 한다")
        XCTAssertEqual(store.moments(on: "2026-09-10").map(\.fileName), ["before.jpg", "after.jpg"],
                       "시간축에는 마무리 뒤 사진도 그대로 보여야 한다")
    }

    func testPhotoTakenBeforeEarlyFinishStaysInThePebble() {
        let closeAt = date(2026, 9, 10, 20, 0)
        closures.close("2026-09-10", at: closeAt)
        store.add(moment(date(2026, 9, 10, 19, 0), name: "before.jpg"))

        XCTAssertEqual(store.pebbleMoments(on: "2026-09-10").map(\.fileName), ["before.jpg"])
    }
}
