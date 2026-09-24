import SwiftUI
import XCTest
@testable import ColorMoments

/// 실기기 멈춤 보고(iCloud 대량 수신·사진첩 담기·카드 건네기)의 메인 스레드 비용을 합성 데이터로 잰다.
/// 시뮬레이터(맥) 수치라 실기기는 몇 배 느리다 — 상한은 회귀만 잡을 만큼 넉넉하게 둔다.
@MainActor
final class PerformanceTests: XCTestCase {

    private var tempFile: URL!
    private var closures: DayClosures!
    private var gifts: GiftLog!

    override func setUp() {
        super.setUp()
        tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("perf-\(UUID().uuidString).json")
        closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        gifts = GiftLog(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFile)
        super.tearDown()
    }

    private static let dayCount = 400
    private static let momentCount = 3_000

    /// 400일에 3,000장 — cloudID·단어·장소가 모두 붙은 받은 기록 모양.
    private func synthetic(_ n: Int = momentCount, days: Int = dayCount) -> [Moment] {
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

    @discardableResult
    private func time(_ label: String, _ block: () -> Void) -> Double {
        let t = CFAbsoluteTimeGetCurrent()
        block()
        let ms = (CFAbsoluteTimeGetCurrent() - t) * 1000
        print("measured perf.\(label): \(String(format: "%.1f", ms)) ms")
        return ms
    }

    private func freshStore() -> DayStore {
        let s = DayStore(fileURL: tempFile, closures: closures)
        s.onLocalChange = { _ in }
        return s
    }

    func testApplyRemoteThreeThousandAtOnce() {
        let store = freshStore()
        let incoming = synthetic()
        time("a.applyRemote3000") { store.applyRemote(upserts: incoming, deletes: []) }
        XCTAssertEqual(store.moments.count, Self.momentCount)
    }

    /// CKSyncEngine 은 받은 변경을 여러 묶음으로 나눠 준다 — 묶음마다 applyRemote + resolveAssets.
    func testApplyRemoteInBatchesWithResolve() {
        let store = freshStore()
        let incoming = synthetic()
        let batched = time("a2.applyRemote15x200+resolve") {
            for chunk in stride(from: 0, to: incoming.count, by: 200) {
                let part = Array(incoming[chunk..<min(chunk + 200, incoming.count)])
                store.applyRemote(upserts: part, deletes: [])
                store.resolveAssets(part.map { ($0.id, "L/\($0.cloudID!)") })
            }
        }
        XCTAssertEqual(store.moments.filter { $0.assetID != nil }.count, Self.momentCount)
        XCTAssertLessThan(batched, 300, "묶음마다 days.json 전체를 메인에서 쓰면 수신량 제곱으로 늘어난다(수정 전 623ms)")
    }

    func testSetCloudIDsAndResolveThreeThousand() {
        let store = freshStore()
        store.applyRemote(upserts: synthetic(), deletes: [])
        let ids = store.moments.map(\.id)
        time("b.resolveAssets3000") { store.resolveAssets(ids.map { ($0, "L/\($0.uuidString)") }) }

        let local = freshStoreWith(synthetic().map {
            Moment(id: $0.id, capturedAt: $0.capturedAt, colorHex: $0.colorHex, fileName: $0.fileName,
                   source: .library, assetID: "A\($0.fileName)", addedAt: $0.addedAt)
        })
        time("b.setCloudIDs3000") { local.setCloudIDs(local.moments.map { ($0.id, "C-\($0.fileName)") }) }
    }

    private func freshStoreWith(_ moments: [Moment]) -> DayStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("perf-\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let s = DayStore(fileURL: url, closures: closures)
        s.onLocalChange = { _ in }
        s.applyRemote(upserts: moments, deletes: [])
        return s
    }

    /// 첫날 사진첩에서 여러 장 담기 — 이미 3,000장 있는 저장소에 200번 add.
    func testTwoHundredAddsOnLargeStore() {
        let store = freshStore()
        store.applyRemote(upserts: synthetic(), deletes: [])
        let now = Date()
        let adds = (0..<200).map { i in
            Moment(capturedAt: now.addingTimeInterval(-Double(i) * 60), colorHex: "#334455",
                   fileName: "new\(i)", source: .library, assetID: "N\(i)", addedAt: now, batchID: UUID())
        }
        let adds200 = time("c.add200") { for m in adds { store.add(m) } }
        XCTAssertEqual(store.moments.count, Self.momentCount + 200)
        XCTAssertLessThan(adds200, 1_500, "add 마다 메인에서 전체 저장하면 9초를 넘는다")
        store.flush()
        XCTAssertEqual(DayStore(fileURL: tempFile, closures: closures).moments.count, Self.momentCount + 200,
                       "백그라운드 저장도 마지막 상태까지 남아야 한다")
    }

    /// HomeView body 한 번이 부르는 것들 — 목록 행은 LazyVStack 이라 화면 안 ~8행만 그리지만, 행마다 days 를 다시 읽는다.
    func testHomeBodyComputations() {
        let store = freshStore()
        store.applyRemote(upserts: synthetic(), deletes: [])
        let today = Moment.dayKey(for: Date())
        gifts.markGifted(Moment.dayKey(for: Date().addingTimeInterval(-3 * 86_400)))

        time("d.finishedDayKeys") { _ = store.finishedDayKeys }
        time("d.giftedDays+months+lastYear") {
            let days = store.finishedDayKeys
            let giftedDays = days.filter(gifts.isGifted)
            _ = HomeNavigation.months(of: days)
            _ = Memories.lastYear(today: today, giftedDays: giftedDays)
            _ = Set(Memories.months(giftedDays: giftedDays, today: today))
        }
        let rows = time("d.visibleRows8") {
            for index in 0..<8 {
                let days = store.finishedDayKeys
                let key = days[index]
                _ = index == 0 || String(days[index - 1].prefix(7)) != String(key.prefix(7))
                _ = store.pebbleMoments(on: key)
                _ = store.moments(on: key)
            }
        }
        let allRows = time("d.allRowsPebbleMoments400") {
            for key in store.dayKeys { _ = store.pebbleMoments(on: key); _ = store.moments(on: key) }
        }
        time("d.pendingGift") {
            _ = GiftSchedule.pending(dayKeys: store.dayKeys, today: today, isGifted: gifts.isGifted,
                                     hasSealedMoments: store.hasSealedMoments, isFinished: store.isFinished)
        }
        XCTAssertLessThan(rows, 50, "행마다 전체 기록을 거르면 스크롤이 끊긴다(수정 전 125ms)")
        XCTAssertLessThan(allRows, 300, "수정 전 3.5초")
    }

    /// 앱 시작 때 DayStore init 이 메인에서 days.json 을 읽는 비용 — 이번엔 고치지 않고 기록만.
    func testLoadThreeThousandFromDisk() {
        let store = freshStore()
        store.applyRemote(upserts: synthetic(), deletes: [])
        store.flush()
        var reopened: DayStore?
        time("h.load3000") { reopened = DayStore(fileURL: tempFile, closures: closures) }
        XCTAssertEqual(reopened?.moments.count, Self.momentCount)
    }

    func testWidgetSnapshotMake() {
        let store = freshStore()
        store.applyRemote(upserts: synthetic(), deletes: [])
        let widget = time("e.WidgetSnapshot.make") { _ = WidgetSnapshot.make(store: store, gifts: gifts) }
        XCTAssertLessThan(widget, 300, "수정 전 1.8초")
    }

    func testCardRender() async {
        let store = freshStore()
        store.applyRemote(upserts: synthetic(), deletes: [])
        let key = store.dayKeys[5]
        let pebble = store.pebbleMoments(on: key)
        _ = CardExporter.render(dayKey: key, pebbleMoments: pebble) // 폰트·질감 첫 로드 제외
        var card: UIImage?
        time("f.cardRender") { card = CardExporter.render(dayKey: key, pebbleMoments: pebble) }
        XCTAssertNotNil(card)

        let groups = store.dayKeys.prefix(31).map { store.pebbleMoments(on: $0) }
        var handful: UIImage?
        time("f.handfulRender31") { handful = CardExporter.renderHandful(month: "2026-08", pebbleGroups: Array(groups)) }
        XCTAssertNotNil(handful)

        if let card {
            time("f.isBlank") { _ = CardExporter.isBlank(card) }
            // ShareLink(item: Image) 는 건네기를 누르는 순간 메인에서 PNG 로 굽는다.
            time("f.pngEncode") { _ = card.pngData() }
        }

        // 시트가 메인에서 쓰는 몫(렌더)과 메인 밖 몫(빈 판정·PNG·미리보기)을 나눠 잰다.
        var raw: UIImage?
        let mainPart = time("f.sheetMainRender") { raw = CardExporter.renderRaw(dayKey: key, pebbleMoments: pebble) }
        let t = CFAbsoluteTimeGetCurrent()
        let prepared = await CardExporter.prepare(raw)
        print("measured perf.f.prepareOffMain: \(String(format: "%.1f", (CFAbsoluteTimeGetCurrent() - t) * 1000)) ms")
        XCTAssertNotNil(prepared)
        XCTAssertEqual(prepared?.png.data.isEmpty, false)
        XCTAssertLessThan(mainPart, 500)
    }
}
