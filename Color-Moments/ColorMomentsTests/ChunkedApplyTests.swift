import CloudKit
import XCTest
@testable import ColorMoments

/// 큰 수신을 조각으로 나눠 넣어도 한 번에 넣은 것과 같은 결과·같은 push 인지.
@MainActor
final class ChunkedApplyTests: XCTestCase {

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

    private func store(with moments: [Moment]) -> DayStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("chunk-\(UUID().uuidString).json")
        files.append(url)
        let s = DayStore(fileURL: url, closures: closures)
        s.add(contentsOf: moments)
        s.onLocalChange = { _ in }
        return s
    }

    private let base = Date(timeIntervalSince1970: 1_780_000_000)

    private func m(_ i: Int, id: UUID = UUID(), cloud: String?, asset: String? = nil,
                   word: Bool = false, added: Double = 0) -> Moment {
        Moment(id: id, capturedAt: base.addingTimeInterval(Double(i) * 1_800), colorHex: String(format: "#%06X", i * 331),
               fileName: asset.map(Moment.assetFileName(for:)) ?? "L\(i)-\(id.uuidString.prefix(4))",
               source: .library, word: word ? PhotoWord(wordID: "w\(i)", word: "말", meaning: "뜻") : nil,
               labels: word ? ["sky"] : nil, assetID: asset, addedAt: base.addingTimeInterval(added), cloudID: cloud)
    }

    /// 로컬 60장(일부는 사진 연결) + 받은 170장: 같은 id 병합, 같은 cloudID 합치기(조각 경계를 넘는 짝 포함),
    /// 받은 것끼리 같은 cloudID, 사진 연결을 넘겨받는 delete.
    private func scenario() -> (local: [Moment], upserts: [Moment], deletes: Set<UUID>) {
        var local: [Moment] = []
        var upserts: [Moment] = []
        var deletes = Set<UUID>()
        for i in 0..<60 {
            local.append(m(i, cloud: i % 3 == 0 ? "C\(i)" : nil, asset: i % 2 == 0 ? "A\(i)" : nil))
        }
        for i in 0..<20 {  // 같은 id — 원격이 단어를 채워 옴
            let l = local[i]
            upserts.append(Moment(id: l.id, capturedAt: l.capturedAt, colorHex: l.colorHex, fileName: "x", source: .library,
                                  word: PhotoWord(wordID: "r\(i)", word: "윤슬", meaning: "잔물결"), labels: ["sea"],
                                  addedAt: l.addedAt, cloudID: l.cloudID ?? "N\(i)"))
        }
        for i in stride(from: 21, to: 60, by: 3) {  // 다른 id, 같은 cloudID — 합치기
            upserts.append(m(i, cloud: "C\(i)", word: true, added: -100))
        }
        for i in 100..<220 { upserts.append(m(i, cloud: "R\(i)", word: i % 2 == 0)) }
        for i in [105, 139, 180] { upserts.append(m(i, cloud: "R\(i)", word: true, added: 50)) }  // 받은 것끼리 짝
        // 사진 연결된 로컬을 지우며 같은 cloudID 의 받은 기록에 넘긴다
        let doomed = m(300, cloud: "D1", asset: "A300")
        local.append(doomed)
        upserts.append(m(300, cloud: "D1"))
        deletes.insert(doomed.id)
        deletes.insert(local[7].id)
        return (local, upserts, deletes)
    }

    func testChunkedApplyMatchesSingleApply() async {
        let s = scenario()
        XCTAssertGreaterThan(s.upserts.count, DayStore.remoteChunkThreshold)
        let once = store(with: s.local)
        let chunked = store(with: s.local)
        XCTAssertEqual(once.moments, chunked.moments)

        let pushOnce = once.applyRemote(upserts: s.upserts, deletes: s.deletes)
        var pauses = 0
        let pushChunked = await chunked.applyRemoteInChunks(upserts: s.upserts, deletes: s.deletes) { pauses += 1 }

        XCTAssertEqual(pauses, (s.upserts.count - 1) / DayStore.remoteChunkSize)
        XCTAssertEqual(chunked.moments, once.moments)
        XCTAssertEqual(pushChunked, pushOnce)
        XCTAssertTrue(pushOnce.contains { if case .delete = $0 { true } else { false } }, "합치기가 실제로 일어나야 의미 있다")
        XCTAssertFalse(chunked.moments.contains { s.deletes.contains($0.id) })
    }

    /// 조각 사이에 쉬는 동안 이 기기에서 지운 기록은 뒤 조각의 원격 upsert 로 되살아나지 않는다.
    func testRemovedBetweenChunksIsNotRevived() async {
        let local = m(0, cloud: "K0")
        let s = store(with: [local])
        var pendingDeletes = Set<UUID>()
        s.onLocalChange = { changes in
            for c in changes { if case .delete(let id) = c { pendingDeletes.insert(id) } }
        }
        var upserts = (1..<130).map { m($0, cloud: "Q\($0)") }
        let edited = Moment(id: local.id, capturedAt: local.capturedAt, colorHex: local.colorHex, fileName: "x",
                            source: .library, word: PhotoWord(wordID: "e", word: "윤슬", meaning: "잔물결"),
                            labels: ["sea"], addedAt: local.addedAt, cloudID: "K0")
        upserts.insert(edited, at: 100)
        var pauses = 0
        await s.applyRemoteInChunks(upserts: upserts, deletes: [], excluding: { pendingDeletes }) {
            pauses += 1
            if pauses == 1 { s.remove(ids: [local.id]) }
        }
        XCTAssertFalse(s.moments.contains { $0.id == local.id })
        XCTAssertEqual(s.moments.count, 129)
    }

    func testSmallBatchDoesNotPause() async {
        let s = store(with: [])
        var pauses = 0
        let upserts = (0..<DayStore.remoteChunkThreshold).map { m($0, cloud: "S\($0)") }
        await s.applyRemoteInChunks(upserts: upserts, deletes: []) { pauses += 1 }
        XCTAssertEqual(pauses, 0)
        XCTAssertEqual(s.moments.count, upserts.count)
    }

    /// 조각 사이에 쉬는 동안 저장소가 쓰는 days.json 도 마지막엔 다 들어간다.
    func testChunkedApplyPersistsEverything() async {
        let s = store(with: [])
        let upserts = (0..<130).map { m($0, cloud: "P\($0)") }
        await s.applyRemoteInChunks(upserts: upserts, deletes: [], pause: FramePause.next)
        s.flush()
        let url = files.last!
        XCTAssertEqual(DayStore(fileURL: url, closures: closures).moments.count, 130)
    }

    func testAddContentsOfMatchesOneByOne() {
        let existing = [m(0, cloud: nil), Moment(capturedAt: base, colorHex: "#000000", fileName: "asset-x",
                                                   source: .locked, originalName: "session-1")]
        let incoming = [
            m(1, cloud: nil),
            Moment(capturedAt: base, colorHex: "#010101", fileName: existing[0].fileName, source: .app),  // 같은 파일
            Moment(capturedAt: base, colorHex: "#020202", fileName: "new", source: .locked, originalName: "session-1"),
            m(2, cloud: nil),
            Moment(capturedAt: base, colorHex: "#030303", fileName: "twice", source: .app),
            Moment(capturedAt: base, colorHex: "#040404", fileName: "twice", source: .app),  // 묶음 안 중복
        ]
        let batch = store(with: existing)
        let single = store(with: existing)
        var batchChanges: [StoreChange] = [], singleChanges: [StoreChange] = []
        batch.onLocalChange = { batchChanges += $0 }
        single.onLocalChange = { singleChanges += $0 }
        let added = batch.add(contentsOf: incoming)
        let singleAdded = incoming.filter { single.add($0) }
        XCTAssertEqual(added, singleAdded)
        XCTAssertEqual(batch.moments, single.moments)
        XCTAssertEqual(batchChanges, singleChanges)
        XCTAssertEqual(added.count, 3)
    }

    func testDecodeMatchesPerRecordConversion() {
        let moments = (0..<5).map { m($0, cloud: "E\($0)", word: true) }
        var records = moments.map { mo -> CKRecord in
            let r = CKRecord(recordType: SyncRecords.momentType, recordID: SyncRecords.recordID(moment: mo.id))
            SyncRecords.fill(r, with: mo)
            return r
        }
        let day = CKRecord(recordType: SyncRecords.dayType, recordID: SyncRecords.recordID(day: "2026-09-01"))
        SyncRecords.fill(day, with: SyncRecords.DayState(dayKey: "2026-09-01", closedAt: base, gifted: true))
        records.append(day)

        let decoded = SyncRecords.decode(records)
        XCTAssertEqual(decoded.moments.map(\.moment), records.compactMap(SyncRecords.moment(from:)))
        XCTAssertEqual(decoded.days.map(\.day), [SyncRecords.DayState(dayKey: "2026-09-01", closedAt: base, gifted: true)])
        XCTAssertEqual(decoded.archived.map(\.recordName), records.map(\.recordID.recordName))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sf-\(UUID().uuidString).json")
        files.append(url)
        let cache = SystemFieldsCache(fileURL: url)
        for (name, data) in decoded.archived { cache.remember(data, for: name) }
        XCTAssertEqual(cache.record(records[2].recordID, type: SyncRecords.momentType).recordID, records[2].recordID)
        XCTAssertEqual(cache.count, records.count)
    }
}
