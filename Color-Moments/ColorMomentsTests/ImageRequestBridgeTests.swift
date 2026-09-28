import UIKit
import XCTest
@testable import ColorMoments

final class ImageRequestBridgeTests: XCTestCase {

    private static let pixel: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }

    func testCallbackTwiceResumesOnceWithFirstImage() async {
        let second = UIImage()
        let result = await ImageRequestBridge.run(
            start: { deliver in
                deliver(Self.pixel)
                deliver(second)
                return 1
            },
            cancel: { _ in XCTFail("끝난 요청을 거뒀다") }
        )
        XCTAssertTrue(result === Self.pixel, "두 번째 콜백이 결과를 덮었다")
    }

    func testCancelWhilePendingCancelsRequestAndReturnsNil() async {
        let log = CancelLog()
        let pending = PendingDeliver()
        let task = Task {
            await ImageRequestBridge.run(
                start: { deliver in pending.set(deliver); return 7 },
                cancel: { log.record($0) }
            )
        }
        await pending.waitStarted()
        task.cancel()
        let result = await task.value
        XCTAssertNil(result)
        XCTAssertEqual(log.ids, [7], "취소했는데 요청을 거두지 않았다")
        pending.deliver(Self.pixel) // 뒤늦은 콜백 — 두 번 풀면 여기서 크래시
    }

    func testAlreadyCancelledNeverStartsRequest() async {
        let started = CancelLog()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await ImageRequestBridge.run(
                start: { _ in started.record(1); return 1 },
                cancel: { _ in }
            )
        }
        let result = await task.value
        XCTAssertNil(result)
        XCTAssertEqual(started.ids, [], "이미 취소된 작업이 요청을 시작했다")
    }
}

final class CancelLog: @unchecked Sendable {
    private let lock = NSLock()
    private var _ids: [Int] = []
    var ids: [Int] { lock.lock(); defer { lock.unlock() }; return _ids }
    func record(_ id: Int) { lock.lock(); _ids.append(id); lock.unlock() }
}

private final class PendingDeliver: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (UIImage?) -> Void)?

    func set(_ h: @escaping @Sendable (UIImage?) -> Void) { lock.lock(); handler = h; lock.unlock() }
    func deliver(_ image: UIImage?) { lock.lock(); let h = handler; lock.unlock(); h?(image) }

    func waitStarted() async {
        while true {
            lock.lock(); let ready = handler != nil; lock.unlock()
            if ready { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}
