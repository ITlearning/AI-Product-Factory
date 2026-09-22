import XCTest
@testable import ColorMoments

final class DayStoreTests: XCTestCase {

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

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: c)!
    }

    private func moment(_ at: Date, _ hex: String = "#112233", name: String? = nil) -> Moment {
        Moment(capturedAt: at, colorHex: hex,
               fileName: name ?? "shot-\(Int(at.timeIntervalSince1970)).jpg", source: .app)
    }

    /// 하루의 경계는 자정이 아니라 새벽 4시다. 사람의 하루는 잠으로 끊긴다.
    func testDayBoundaryIsFourInTheMorning() {
        XCTAssertEqual(Moment.dayKey(for: date(2026, 9, 22, 23, 30)), "2026-09-22")
        XCTAssertEqual(Moment.dayKey(for: date(2026, 9, 23, 1, 0)), "2026-09-22",
                       "새벽 1시는 아직 어제여야 한다")
        XCTAssertEqual(Moment.dayKey(for: date(2026, 9, 23, 3, 59)), "2026-09-22",
                       "3시 59분까지 어제")
        XCTAssertEqual(Moment.dayKey(for: date(2026, 9, 23, 4, 0)), "2026-09-23",
                       "4시부터 오늘")
    }

    /// 밤새 이어 찍은 것이 한 하루로 묶여야 그라데이션이 끊기지 않는다.
    func testNightShotsGroupIntoOneDay() {
        store.add(moment(date(2026, 9, 22, 22, 0), name: "a.jpg"))
        store.add(moment(date(2026, 9, 23, 0, 30), name: "b.jpg"))
        store.add(moment(date(2026, 9, 23, 2, 0), name: "c.jpg"))
        store.add(moment(date(2026, 9, 23, 9, 0), name: "d.jpg"))

        XCTAssertEqual(store.moments(on: "2026-09-22").count, 3)
        XCTAssertEqual(store.moments(on: "2026-09-23").count, 1)
    }

    func testMomentsAreReturnedInCaptureOrder() {
        store.add(moment(date(2026, 9, 22, 18, 0), name: "late.jpg"))
        store.add(moment(date(2026, 9, 22, 9, 0), name: "early.jpg"))
        XCTAssertEqual(store.moments(on: "2026-09-22").map(\.fileName), ["early.jpg", "late.jpg"])
    }

    /// 수신함이 재실행되면 같은 파일을 다시 들여올 수 있다. 중복이 쌓이면 안 된다.
    func testDuplicateFileNameIsIgnored() {
        store.add(moment(date(2026, 9, 22, 12, 0), name: "same.jpg"))
        store.add(moment(date(2026, 9, 22, 13, 0), name: "same.jpg"))
        XCTAssertEqual(store.moments.count, 1)
    }

    func testPersistsAcrossInstances() {
        store.add(moment(date(2026, 9, 22, 12, 0), "#AABBCC", name: "p.jpg"))
        let reopened = DayStore(fileURL: tempFile)
        XCTAssertEqual(reopened.moments.count, 1)
        XCTAssertEqual(reopened.moments.first?.colorHex, "#AABBCC")
    }

    /// 탭 보정. 사용자가 고른 색은 「직접 고름」으로 남아야 나중에 자동값과 구분된다.
    func testColorCorrectionMarksChosen() {
        let m = moment(date(2026, 9, 22, 12, 0), "#111111", name: "fix.jpg")
        store.add(m)
        store.updateColor(m.id, to: "#F0A896")
        XCTAssertEqual(store.moments.first?.colorHex, "#F0A896")
        XCTAssertEqual(store.moments.first?.colorWasChosen, true)
        XCTAssertEqual(store.moments.first?.capturedAt, m.capturedAt, "시각은 안 바뀌어야 한다")
    }

    func testRemoveAllEmptiesTheStore() {
        store.add(moment(date(2026, 9, 22, 12, 0), name: "x.jpg"))
        store.removeAll()
        XCTAssertTrue(store.moments.isEmpty)
        XCTAssertTrue(DayStore(fileURL: tempFile).moments.isEmpty, "파일에서도 지워져야 한다")
    }
}
