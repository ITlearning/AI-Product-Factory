import CloudKit
import XCTest
@testable import ColorMoments

/// iCloud 대량 수신에서 CloudSync.apply 가 묶음마다 메인에서 하던 일 — 레코드 → Moment, 시스템 필드 보관·파일 쓰기.
@MainActor
final class SyncPerformanceTests: XCTestCase {

    private func records(_ n: Int) -> [CKRecord] {
        let start = Date().addingTimeInterval(-400 * 86_400)
        return (0..<n).map { i in
            let m = Moment(capturedAt: start.addingTimeInterval(Double(i) * 3600), colorHex: "#A1B2C3",
                           fileName: "f\(i)", source: .library,
                           word: PhotoWord(wordID: "w1", word: "윤슬", meaning: "잔물결"), labels: ["sky"],
                           place: Place(latitude: 37.5, longitude: 127, accuracy: 20),
                           addedAt: start, batchID: UUID(), cloudID: "CLOUD/\(i)")
            let r = CKRecord(recordType: SyncRecords.momentType, recordID: SyncRecords.recordID(moment: m.id))
            SyncRecords.fill(r, with: m)
            return r
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

    /// 받은 레코드 처리 쪼개기 — 레코드 → Moment 변환과 시스템 필드 아카이브 중 어디가 무거운지.
    func testReceiveBreakdown() {
        let all = records(3_000)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sf-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let fields = SystemFieldsCache(fileURL: url)
        time("g.convert3000") { for r in all { _ = SyncRecords.moment(from: r) } }
        time("g.remember3000") { for r in all { fields.remember(r) } }
    }

    /// 고친 뒤 메인 몫 — 변환·아카이브는 밖에서, 메인은 사전 넣기 + 조각 applyRemote + 쓰기 예약만.
    /// 조각 사이 쉬는 틈마다 끊어 가장 긴 한 덩어리(프레임을 막는 시간)도 잰다.
    func testReceiveMainShareAfterOffMainDecode() async {
        let all = records(3_000)
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("sf-\(UUID().uuidString).json")
        let daysURL = dir.appendingPathComponent("days-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: daysURL) }
        let fields = SystemFieldsCache(fileURL: url)
        let store = DayStore(fileURL: daysURL, closures: DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        store.onLocalChange = { _ in }
        var total = 0.0, longest = 0.0
        var mark = CFAbsoluteTimeGetCurrent()
        func lap() {
            let ms = (CFAbsoluteTimeGetCurrent() - mark) * 1000
            total += ms
            longest = max(longest, ms)
        }
        for chunk in stride(from: 0, to: all.count, by: 200) {
            let batch = Array(all[chunk..<min(chunk + 200, all.count)])
            let decoded = await Task.detached { SyncRecords.decode(batch) }.value
            mark = CFAbsoluteTimeGetCurrent()
            for (name, data) in decoded.archived { fields.remember(data, for: name) }
            await store.applyRemoteInChunks(upserts: decoded.moments.map(\.moment), deletes: []) {
                lap()
                await Task.yield()
                mark = CFAbsoluteTimeGetCurrent()
            }
            fields.persist()
            lap()
        }
        print("measured perf.g.mainShare15x200: \(String(format: "%.1f", total)) ms")
        print("measured perf.g.longestMainSlice: \(String(format: "%.1f", longest)) ms")
        XCTAssertEqual(store.moments.count, 3_000)
        XCTAssertLessThan(longest, 25)
    }

    /// 3,000건을 200건씩 15묶음으로 받을 때 메인에서 쓰는 시간 — 묶음마다 누적된 시스템 필드 전체를 파일로 쓴다.
    func testReceiveFifteenBatchesOfSystemFields() {
        let all = records(3_000)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sf-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let fields = SystemFieldsCache(fileURL: url)
        let ms = time("g.systemFields15x200") {
            for chunk in stride(from: 0, to: all.count, by: 200) {
                for r in all[chunk..<min(chunk + 200, all.count)] {
                    fields.remember(r)
                    _ = SyncRecords.moment(from: r)
                }
                fields.persist()
            }
        }
        fields.flush()
        let reloaded = SystemFieldsCache(fileURL: url)
        XCTAssertEqual(reloaded.count, 3_000, "백그라운드로 쓴 시스템 필드가 다시 읽혀야 한다")
        XCTAssertNotNil(reloaded.record(all[7].recordID, type: SyncRecords.momentType))
        XCTAssertLessThan(ms, 552)
    }
}
