import UIKit
import XCTest
@testable import ColorMoments

/// 가짜 사진 앱 — 요청마다 delay 만큼 기다리고, 동시에 몇 개 돌았는지·취소가 몇 번 닿았는지 센다.
private final class SlowAssetSource: AssetImageSource, @unchecked Sendable {
    private let lock = NSLock()
    private let delay: UInt64
    private var inFlight = 0
    private(set) var maxInFlight = 0
    private(set) var started: [String] = []
    private(set) var cancelled: [String] = []

    init(delayMillis: UInt64) { delay = delayMillis * 1_000_000 }

    func snapshot() -> (max: Int, started: [String], cancelled: [String]) {
        lock.lock(); defer { lock.unlock() }
        return (maxInFlight, started, cancelled)
    }

    func image(assetID: String, maxPixel: CGFloat) async -> UIImage? {
        lock.lock()
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
        started.append(assetID)
        lock.unlock()
        defer { lock.lock(); inFlight -= 1; lock.unlock() }
        do {
            try await Task.sleep(nanoseconds: delay)
        } catch {
            lock.lock(); cancelled.append(assetID); lock.unlock()
            return nil
        }
        return UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
    }
}

final class ThumbnailLoadingTests: XCTestCase {

    override func tearDown() {
        ShotImage.assetSource = nil
        super.tearDown()
    }

    private func moment(_ assetID: String) -> Moment {
        Moment(capturedAt: Date(), colorHex: "#112233",
               fileName: Moment.assetFileName(for: assetID), source: .library, assetID: assetID)
    }

    func testThumbnailRequestsAreCappedAtSix() async {
        let source = SlowAssetSource(delayMillis: 40)
        ShotImage.assetSource = source
        let ms = (0..<20).map { moment("CAP-\($0)-\(UUID().uuidString)") }

        let loaded = await withTaskGroup(of: Bool.self) { group in
            for m in ms { group.addTask { await ShotImage.thumbnail(m, maxPixel: 100) != nil } }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }

        let s = source.snapshot()
        XCTAssertEqual(loaded, 20, "상한 때문에 빠진 요청이 있다")
        XCTAssertLessThanOrEqual(s.max, 6, "동시 요청이 상한을 넘었다")
        XCTAssertGreaterThan(s.max, 1, "상한이 요청을 한 줄로만 세웠다")
    }

    func testCancellingTheTaskCancelsTheRunningRequest() async {
        let source = SlowAssetSource(delayMillis: 5_000)
        ShotImage.assetSource = source
        let m = moment("RUN-\(UUID().uuidString)")

        let task = Task { await ShotImage.warm(m, maxPixel: 100) }
        while source.snapshot().started.isEmpty { try? await Task.sleep(nanoseconds: 1_000_000) }
        task.cancel()
        let result = await task.value

        XCTAssertNil(result)
        XCTAssertEqual(source.snapshot().cancelled, [m.assetID!], "작업을 취소했는데 요청에 닿지 않았다")
        XCTAssertNil(ShotImage.peek(m, maxPixel: 100), "취소된 결과가 캐시에 남았다")
    }

    func testCancelledWaiterLeavesWithoutStartingRequest() async {
        let source = SlowAssetSource(delayMillis: 300)
        ShotImage.assetSource = source
        let busy = (0..<6).map { moment("BUSY-\($0)-\(UUID().uuidString)") }
        let busyTasks = busy.map { m in Task { await ShotImage.thumbnail(m, maxPixel: 100) } }
        while source.snapshot().started.count < 6 { try? await Task.sleep(nanoseconds: 1_000_000) }

        let waiting = moment("WAIT-\(UUID().uuidString)")
        let clock = ContinuousClock()
        let begin = clock.now
        let waiter = Task { await ShotImage.thumbnail(waiting, maxPixel: 100) }
        try? await Task.sleep(nanoseconds: 20_000_000)
        waiter.cancel()
        let result = await waiter.value
        let waited = clock.now - begin

        XCTAssertNil(result)
        XCTAssertLessThan(waited, .milliseconds(250), "취소된 대기자가 자리가 날 때까지 붙잡혀 있었다")
        for t in busyTasks { _ = await t.value }
        XCTAssertFalse(source.snapshot().started.contains(waiting.assetID!), "취소된 대기자가 요청을 시작했다")
    }
}
