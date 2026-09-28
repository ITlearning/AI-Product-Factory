import Observation
import XCTest
@testable import ColorMoments

/// 재설치 뒤 iCloud 대량 수신 — 조각을 넣을 때마다 홈이 다시 그려지는 비용까지 함께 잰다.
/// 홈 body 는 관찰(withObservationTracking)이 바뀌었다고 알린 프레임에만 다시 돈다 — SwiftUI 와 같은 조건.
/// 한 조각 넣기 + 그 프레임의 홈 다시 그리기가 한 런루프 턴이라 둘을 더한 것이 한 번의 끊김이다.
@MainActor
final class BulkReceivePerformanceTests: XCTestCase {

    private var files: [URL] = []

    override func tearDown() {
        files.forEach { try? FileManager.default.removeItem(at: $0) }
        super.tearDown()
    }

    private func synthetic(_ n: Int) -> [Moment] {
        let days = max(1, n * 2 / 15)
        let start = Date().addingTimeInterval(-Double(days + 2) * 86_400)
        return (0..<n).map { i in
            let day = i % days
            let at = start.addingTimeInterval(Double(day) * 86_400 + 8 * 3600 + Double(i / days) * 900)
            return Moment(capturedAt: at, colorHex: String(format: "#%06X", (i * 7919) & 0xFFFFFF),
                          fileName: "f\(i)", source: .library,
                          word: PhotoWord(wordID: "w\(i % 50)", word: "단어\(i % 50)", meaning: "뜻"), labels: ["sky"],
                          place: Place(latitude: 37.5, longitude: 127, accuracy: 10),
                          addedAt: at, batchID: UUID(), cloudID: "C\(i)")
        }
    }

    private func freshStore() -> (DayStore, GiftLog) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bulk-\(UUID().uuidString).json")
        files.append(url)
        let closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let store = DayStore(fileURL: url, closures: closures)
        store.onLocalChange = { _ in }
        let gifts = GiftLog(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        gifts.markGifted(Moment.dayKey(for: Date().addingTimeInterval(-3 * 86_400)))
        return (store, gifts)
    }

    /// HomeView·HomeShell body 가 한 번에 읽는 것 — 화면 안 8행.
    private func homeBody(_ store: DayStore, _ gifts: GiftLog) {
        HomeBodyModel.evaluate(store: store, gifts: gifts, visibleRows: 8)
    }

    private struct Result {
        var total = 0.0, longest = 0.0, homePasses = 0, homeTotal = 0.0
    }

    private func receive(_ n: Int) async -> Result {
        let (store, gifts) = freshStore()
        let incoming = synthetic(n)
        var r = Result()
        var dirty = false
        func renderIfDirty() -> Double {
            guard dirty else { return 0 }
            dirty = false
            let t = CFAbsoluteTimeGetCurrent()
            withObservationTracking { homeBody(store, gifts) } onChange: { dirty = true }
            let ms = (CFAbsoluteTimeGetCurrent() - t) * 1000
            r.homePasses += 1
            r.homeTotal += ms
            return ms
        }
        withObservationTracking { homeBody(store, gifts) } onChange: { dirty = true }

        // CKSyncEngine 은 200건 안팎으로 나눠 준다 — 묶음마다 applyRemoteInChunks.
        var mark = CFAbsoluteTimeGetCurrent()
        func slice() {
            let applyMs = (CFAbsoluteTimeGetCurrent() - mark) * 1000
            let ms = applyMs + renderIfDirty()
            r.total += ms
            r.longest = max(r.longest, ms)
        }
        for start in stride(from: 0, to: incoming.count, by: 200) {
            let batch = Array(incoming[start..<min(start + 200, incoming.count)])
            mark = CFAbsoluteTimeGetCurrent()
            await store.applyRemoteInChunks(upserts: batch, deletes: []) {
                slice()
                await FramePause.next()
                mark = CFAbsoluteTimeGetCurrent()
            }
            slice()
            await FramePause.next()
        }
        // 수신이 끝난 뒤 합쳐 둔 갱신이 남아 있으면 마지막으로 한 번 그린다.
        for _ in 0..<12 {
            await FramePause.next()
            r.total += renderIfDirty()
        }
        XCTAssertEqual(store.moments.count, n)
        XCTAssertEqual(HomeBodyModel.days(store: store).count, store.finishedDayKeys.count)
        return r
    }

    private func report(_ label: String, _ r: Result) {
        print("measured perf.i.\(label).mainTotal: \(String(format: "%.1f", r.total)) ms")
        print("measured perf.i.\(label).longestSlice: \(String(format: "%.1f", r.longest)) ms")
        print("measured perf.i.\(label).homePasses: \(r.homePasses)")
        print("measured perf.i.\(label).homeTotal: \(String(format: "%.1f", r.homeTotal)) ms")
    }

    func testBulkReceiveThreeThousandWithHome() async {
        let r = await receive(3_000)
        report("receive3000", r)
        XCTAssertLessThanOrEqual(r.homePasses, 30, "조각(75개)마다 홈을 다시 그리면 안 된다")
        XCTAssertLessThan(r.total, 364, "수정 전 800ms")
    }

    func testBulkReceiveFiveThousandWithHome() async {
        let r = await receive(5_000)
        report("receive5000", r)
        XCTAssertLessThanOrEqual(r.homePasses, 50, "조각(125개)마다 홈을 다시 그리면 안 된다")
        XCTAssertLessThan(r.total, 692, "수정 전 2,202ms")
    }

    /// 수신이 다 끝난 뒤 홈 한 번 — 스크롤·다른 갱신 때마다 드는 몫.
    func testHomeBodyOnFiveThousand() {
        let (store, gifts) = freshStore()
        store.applyRemote(upserts: synthetic(5_000), deletes: [])
        homeBody(store, gifts)
        let t = CFAbsoluteTimeGetCurrent()
        for _ in 0..<10 { homeBody(store, gifts) }
        let ms = (CFAbsoluteTimeGetCurrent() - t) * 100
        print("measured perf.i.homeBodyWarm5000: \(String(format: "%.2f", ms)) ms")
        XCTAssertLessThan(ms, 1, "수정 전 7.95ms — 행마다 finishedDayKeys 를 다시 걸렀다")
    }
}

/// HomeView·HomeShell body 가 읽는 것을 그대로 옮긴 모형 — HomeView 를 바꾸면 이것도 같이 바꾼다.
@MainActor
enum HomeBodyModel {

    static func days(store: DayStore) -> [String] { store.home(gifts: GiftLog(defaults: UserDefaults(suiteName: UUID().uuidString)!)).days }

    static func evaluate(store: DayStore, gifts: GiftLog, visibleRows: Int) {
        let today = Moment.dayKey(for: Date())
        let home = { store.home(gifts: gifts) }
        // HomeShell.onChange(of: store.dayKeys)
        _ = store.dayKeys
        // backdrop
        if let key = home().days.first { _ = store.pebbleMoments(on: key) }
        // todayInProgress / todayClosedWithMoments
        _ = !store.today.isEmpty && !store.isFinished(today)
        _ = !store.today.isEmpty && store.isFinished(today)
        _ = store.today.count
        // lastYearLine
        if let k = home().lastYearDayKey { _ = store.pebbleMoments(on: k) }
        _ = home().days.isEmpty
        for row in home().rows.prefix(visibleRows) {
            _ = row.hasHeader
            _ = Keepsake.canMakeCard(dayKey: row.key, isGifted: gifts.isGifted)
            _ = store.pebbleMoments(on: row.key)
            _ = store.moments(on: row.key)
        }
        // appearanceIDs (onChange(of:) 가 body 마다 한 번)
        _ = home().appearanceIDs
        _ = store.moments.isEmpty
    }
}
