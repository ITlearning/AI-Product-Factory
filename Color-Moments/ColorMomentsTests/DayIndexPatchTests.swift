import Observation
import XCTest
@testable import ColorMoments

/// 조각마다 인덱스를 통째로 다시 만들지 않고 고쳐 붙여도 처음부터 만든 것과 같은지, 화면 알림은 묶이는지.
@MainActor
final class DayIndexPatchTests: XCTestCase {

    private var files: [URL] = []
    private var closures: DayClosures!

    override func setUp() {
        super.setUp()
        closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    override func tearDown() {
        files.forEach { try? FileManager.default.removeItem(at: $0) }
        super.tearDown()
    }

    private func store() -> DayStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("patch-\(UUID().uuidString).json")
        files.append(url)
        let s = DayStore(fileURL: url, closures: closures)
        s.onLocalChange = { _ in }
        return s
    }

    private let base = Date(timeIntervalSince1970: 1_780_000_000)

    private func m(_ i: Int, id: UUID = UUID(), cloud: String?, asset: String? = nil, word: Bool = false) -> Moment {
        Moment(id: id, capturedAt: base.addingTimeInterval(Double(i) * 5_000), colorHex: String(format: "#%06X", i * 331),
               fileName: asset.map(Moment.assetFileName(for:)) ?? "L\(i)-\(id.uuidString.prefix(4))",
               source: .library, word: word ? PhotoWord(wordID: "w\(i)", word: "말", meaning: "뜻") : nil,
               labels: word ? ["sky"] : nil, assetID: asset, addedAt: base, cloudID: cloud)
    }

    func testPatchedIndexMatchesRebuildAcrossChunksMergesAndDeletes() async {
        let s = store()
        var local = (0..<60).map { m($0, cloud: $0 % 3 == 0 ? "C\($0)" : nil, asset: $0 % 2 == 0 ? "A\($0)" : nil) }
        let doomed = m(300, cloud: "D1", asset: "A300")
        local.append(doomed)
        s.add(contentsOf: local)
        _ = s.dayKeys  // 인덱스를 먼저 만들어 둬야 고쳐 붙이는 길을 탄다
        var upserts = (0..<20).map { i in
            Moment(id: local[i].id, capturedAt: local[i].capturedAt, colorHex: local[i].colorHex, fileName: "x",
                   source: .library, word: PhotoWord(wordID: "r\(i)", word: "윤슬", meaning: "잔물결"), labels: ["sea"],
                   addedAt: local[i].addedAt, cloudID: local[i].cloudID ?? "N\(i)")
        }
        for i in stride(from: 21, to: 60, by: 3) { upserts.append(m(i, cloud: "C\(i)", word: true)) }
        for i in 100..<260 { upserts.append(m(i, cloud: "R\(i)")) }
        upserts.append(m(300, cloud: "D1"))
        var pauses = 0
        await s.applyRemoteInChunks(upserts: upserts, deletes: [doomed.id, local[7].id]) {
            pauses += 1
            XCTAssertTrue(s.indexMatchesRebuild(), "조각 \(pauses) 뒤")
        }
        XCTAssertGreaterThan(pauses, 2)
        XCTAssertTrue(s.indexMatchesRebuild())
        XCTAssertFalse(s.dayKeys.isEmpty)

        s.resolveAssets(s.unresolved.prefix(30).map { ($0.id, "L/\($0.id)") })
        XCTAssertTrue(s.indexMatchesRebuild())
        s.add(contentsOf: [m(900, cloud: nil), m(901, cloud: nil)])
        XCTAssertTrue(s.indexMatchesRebuild())
        s.add(m(902, cloud: nil))
        XCTAssertTrue(s.indexMatchesRebuild())
    }

    /// 조각 사이에 이 기기에서 바뀐 게 있으면(자리가 밀림) 이어 쓰던 사전을 버리고 다시 만든다.
    func testLocalRemovalBetweenChunksStillMatchesSingleApply() async {
        let local = (0..<30).map { m($0, cloud: "K\($0)") }
        let upserts = (0..<130).map { m($0 + 40, cloud: "Q\($0)") } + local.prefix(10).map {
            Moment(id: UUID(), capturedAt: $0.capturedAt, colorHex: $0.colorHex, fileName: "y", source: .library,
                   word: PhotoWord(wordID: "z", word: "말", meaning: "뜻"), labels: ["sky"], addedAt: base, cloudID: $0.cloudID)
        }
        let once = store(), chunked = store()
        once.add(contentsOf: local)
        chunked.add(contentsOf: local)
        _ = chunked.dayKeys
        once.remove(ids: [local[20].id])
        once.applyRemote(upserts: upserts, deletes: [])
        var pauses = 0
        await chunked.applyRemoteInChunks(upserts: upserts, deletes: []) {
            pauses += 1
            if pauses == 1 { chunked.remove(ids: [local[20].id]) }
        }
        XCTAssertEqual(chunked.moments, once.moments)
        XCTAssertTrue(chunked.indexMatchesRebuild())
    }

    /// 조각마다가 아니라 bulkPublishInterval 에 한 번 알린다 — 끝나면 바로 한 번 더.
    func testBulkReceiveCoalescesObservation() async {
        let s = store()
        var fired = 0
        func track() { withObservationTracking { _ = s.dayKeys } onChange: { Task { @MainActor in fired += 1; track() } } }
        track()
        let upserts = (0..<400).map { m($0, cloud: "B\($0)") }
        var pauses = 0
        await s.applyRemoteInChunks(upserts: upserts, deletes: []) {
            pauses += 1
            await Task.yield()
        }
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(pauses, 9)
        XCTAssertGreaterThanOrEqual(fired, 1, "끝나면 반드시 한 번은 알린다")
        XCTAssertLessThan(fired, pauses, "조각마다 알리면 조각 수만큼 홈이 다시 그려진다")
        XCTAssertEqual(s.moments.count, 400)
    }

    /// 대량 수신 밖의 변경은 바로 알린다.
    func testOrdinaryChangePublishesImmediately() {
        let s = store()
        var fired = false
        withObservationTracking { _ = s.moments } onChange: { fired = true }
        s.add(m(1, cloud: nil))
        XCTAssertTrue(fired)
    }
}

/// HomeSummary 가 예전 HomeView 계산(days 필터·월 머리글·등장 id)과 같은 값을 내는지.
final class HomeSummaryTests: XCTestCase {

    func testMatchesOldHomeViewComputation() {
        let today = "2026-09-28"
        let days = ["2026-09-27", "2026-09-20", "2026-08-31", "2026-08-02", "2026-07-15", "2025-09-29", "2025-09-26", "2025-08-01"]
        let isGifted: (String) -> Bool = { $0 <= "2026-08-31" }
        let s = HomeSummary.make(days: days, isGifted: isGifted, today: today)

        let giftedDays = days.filter(isGifted)
        let handful = Set(Memories.months(giftedDays: giftedDays, today: today))
        XCTAssertEqual(s.giftedDays, giftedDays)
        XCTAssertEqual(s.handfulMonths, handful)
        XCTAssertEqual(s.months, HomeNavigation.months(of: days))
        XCTAssertEqual(s.lastYearDayKey, Memories.lastYear(today: today, giftedDays: giftedDays))
        var ids: [String] = []
        var previous: Substring?
        for key in days {
            let month = key.prefix(7)
            if month != previous, handful.contains(String(month)) { ids.append("month-\(month)") }
            previous = month
            ids.append(key)
        }
        XCTAssertEqual(s.appearanceIDs, ids)
        for (index, key) in days.enumerated() {
            let month = String(key.prefix(7))
            let isMonthStart = index == 0 || String(days[index - 1].prefix(7)) != month
            XCTAssertEqual(s.rows[index].hasHeader, isMonthStart && handful.contains(month), key)
            XCTAssertEqual(s.rows[index].index, index)
            XCTAssertEqual(s.firstDayOfMonth[month], days.first { $0.hasPrefix(month) })
        }
        XCTAssertEqual(s.lastYearDayKey, "2025-09-29")
    }

    @MainActor
    func testStoreCachesUntilSomethingChanges() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("home-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let store = DayStore(fileURL: url, closures: closures)
        store.onLocalChange = { _ in }
        let gifts = GiftLog(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let old = Date().addingTimeInterval(-10 * 86_400)
        store.add(Moment(capturedAt: old, colorHex: "#111111", fileName: "a", source: .library))
        let first = store.home(gifts: gifts)
        XCTAssertEqual(first.days, [Moment.dayKey(for: old)])
        XCTAssertTrue(first.giftedDays.isEmpty)
        gifts.markGifted(Moment.dayKey(for: old))
        XCTAssertEqual(store.home(gifts: gifts).giftedDays, [Moment.dayKey(for: old)], "받은 날이 바뀌면 다시 만든다")
        store.add(Moment(capturedAt: old.addingTimeInterval(-86_400), colorHex: "#222222", fileName: "b", source: .library))
        XCTAssertEqual(store.home(gifts: gifts).days.count, 2)
        XCTAssertEqual(store.home(gifts: gifts).days, store.finishedDayKeys)
    }
}
