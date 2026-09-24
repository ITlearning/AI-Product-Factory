import XCTest
@testable import ColorMoments

final class WidgetSnapshotTests: XCTestCase {

    private var closures: DayClosures!
    private var gifts: GiftLog!
    private var store: DayStore!
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        gifts = GiftLog(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("widget-\(UUID().uuidString).json")
        store = DayStore(fileURL: fileURL, closures: closures)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text + "+09:00")!
    }

    @discardableResult
    private func add(_ at: String, _ hex: String) -> Moment {
        let m = Moment(capturedAt: date(at), colorHex: hex, fileName: UUID().uuidString, source: .app)
        store.add(m)
        return m
    }

    func testLatestIsMostRecentGiftedDay() {
        add("2026-09-19T10:00:00", "#111111")
        add("2026-09-20T09:00:00", "#AA0000")
        add("2026-09-20T18:00:00", "#00AA00")
        gifts.markGifted("2026-09-20")

        let s = WidgetSnapshot.make(store: store, gifts: gifts)
        XCTAssertEqual(s.latest?.dayKey, "2026-09-20")
        XCTAssertEqual(s.latest?.colors.map(\.hex), ["#AA0000", "#00AA00"], "pebbleMoments 순서 그대로여야 한다")
        XCTAssertEqual(s.latest?.name, PebbleNaming.name(for: store.pebbleMoments(on: "2026-09-20"))?.name)
        XCTAssertEqual(s.latest?.moments.map(\.dayKey), ["2026-09-20", "2026-09-20"],
                       "되살린 Moment 의 dayKey 가 같아야 실루엣이 앱과 같다")
        XCTAssertEqual(s.latest?.dateText, "9월 20일")
        XCTAssertTrue(s.arrivals.isEmpty, "받은 날 이하는 도착 대상이 아니다")
    }

    func testUngiftedDaysBecomeArrivalsAtSealDate() {
        add("2026-09-20T09:00:00", "#AA0000")
        gifts.markGifted("2026-09-20")
        add("2026-09-21T12:00:00", "#0000AA")
        add("2026-09-22T12:00:00", "#00AAAA")
        closures.close("2026-09-22", at: date("2026-09-22T20:00:00"))

        let s = WidgetSnapshot.make(store: store, gifts: gifts)
        XCTAssertEqual(s.latest?.dayKey, "2026-09-20")
        XCTAssertEqual(s.arrivals.map(\.dayKey), ["2026-09-21", "2026-09-22"])
        XCTAssertEqual(s.arrivals.map(\.arrivesAt),
                       [store.sealDate(on: "2026-09-21")!, store.sealDate(on: "2026-09-22")!])
        XCTAssertEqual(s.arrivals.last?.arrivesAt, date("2026-09-22T20:00:00"), "일찍 받은 날은 그 시각에 닫힌다")
    }

    func testNothingGiftedAndNothingPendingIsEmpty() {
        let s = WidgetSnapshot.make(store: store, gifts: gifts)
        XCTAssertNil(s.latest)
        XCTAssertTrue(s.arrivals.isEmpty)
        XCTAssertEqual(s.entries(now: Date()).map(\.state), [.empty])
    }

    func testEntriesShowPebbleBeforeArrivalAndArrivingAfter() {
        add("2026-09-20T09:00:00", "#AA0000")
        gifts.markGifted("2026-09-20")
        add("2026-09-21T12:00:00", "#0000AA")

        let s = WidgetSnapshot.make(store: store, gifts: gifts)
        let seal = store.sealDate(on: "2026-09-21")!
        let entries = s.entries(now: seal.addingTimeInterval(-3600))
        XCTAssertEqual(entries.map(\.date), [seal.addingTimeInterval(-3600), seal])
        XCTAssertEqual(entries.first?.state, .pebble(s.latest!))
        XCTAssertEqual(entries.last?.state, .arriving(dayKey: "2026-09-21"))

        XCTAssertEqual(s.entries(now: seal.addingTimeInterval(60)).map(\.state), [.arriving(dayKey: "2026-09-21")],
                       "이미 닫혔으면 지금부터 도착")
    }

    func testArrivalWithoutAnyGiftStartsEmpty() {
        add("2026-09-21T12:00:00", "#0000AA")
        let s = WidgetSnapshot.make(store: store, gifts: gifts)
        let seal = store.sealDate(on: "2026-09-21")!
        XCTAssertEqual(s.entries(now: seal.addingTimeInterval(-60)).map(\.state),
                       [.empty, .arriving(dayKey: "2026-09-21")])
    }

    func testJSONRoundTrip() throws {
        add("2026-09-20T09:00:00", "#AA0000")
        add("2026-09-20T18:00:00", "#00AA00")
        gifts.markGifted("2026-09-20")
        add("2026-09-21T12:00:00", "#0000AA")
        let s = WidgetSnapshot.make(store: store, gifts: gifts)

        XCTAssertEqual(try WidgetSnapshot.decoded(from: s.encoded()), s)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("snap-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        s.write(to: url)
        XCTAssertEqual(WidgetSnapshot.read(from: url), s)
    }

    func testUnreadableFileFallsBackToEmpty() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("none-\(UUID().uuidString).json")
        XCTAssertEqual(WidgetSnapshot.read(from: missing), .empty)
        XCTAssertEqual(WidgetSnapshot.read(from: nil), .empty)
        WidgetSnapshot.empty.write(to: nil)
    }
}
