import UIKit
import XCTest
@testable import ColorMoments

/// 호출마다 성공/실패를 순서대로 내주는 가짜 사진 앱 — assetID 별로 몇 번 불렸는지도 센다.
private final class ScriptedAssetSource: AssetImageSource, @unchecked Sendable {
    private let lock = NSLock()
    private var scripts: [String: [Bool]]
    private(set) var callCounts: [String: Int] = [:]

    init(_ scripts: [String: [Bool]]) { self.scripts = scripts }

    func image(assetID: String, maxPixel: CGFloat) async -> UIImage? {
        lock.lock()
        callCounts[assetID, default: 0] += 1
        var steps = scripts[assetID] ?? []
        let succeeds = steps.isEmpty ? false : steps.removeFirst()
        scripts[assetID] = steps
        lock.unlock()
        guard succeeds else { return nil }
        return UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
    }

    func calls(_ assetID: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return callCounts[assetID] ?? 0
    }
}

/// 불리면 바로 실패하는 가짜 — "재요청 안 함"을 증명할 때 쓴다(불리면 곧장 실패로 드러남).
private final class MustNotBeCalledSource: AssetImageSource, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var calls = 0

    func image(assetID: String, maxPixel: CGFloat) async -> UIImage? {
        lock.lock(); calls += 1; lock.unlock()
        return nil
    }
}

final class ShotImageGenerationTests: XCTestCase {

    override func tearDown() {
        ShotImage.assetSource = nil
        super.tearDown()
    }

    private func moment(_ assetID: String) -> Moment {
        Moment(capturedAt: Date(), colorHex: "#112233",
               fileName: Moment.assetFileName(for: assetID), source: .library, assetID: assetID)
    }

    /// 첫 요청은 nil(사진이 아직 안 내려옴) → 세대가 오른 assetID 만 값이 바뀐다 → 다시 물으면(재요청) 성공.
    func testFirstRequestNilThenGenerationBumpThenRetrySucceeds() async {
        let assetID = "GEN-\(UUID().uuidString)"
        let other = "GEN-OTHER-\(UUID().uuidString)"
        let source = ScriptedAssetSource([assetID: [false, true]])
        ShotImage.assetSource = source
        let m = moment(assetID)

        let first = await ShotImage.warm(m, maxPixel: 100)
        XCTAssertNil(first, "첫 요청은 실패해야 한다")
        XCTAssertNil(ShotImage.peek(m, maxPixel: 100), "실패가 캐시에 남았다(음성 캐시)")

        let beforeAffected = ShotImage.generation.value(for: assetID)
        let beforeOther = ShotImage.generation.value(for: other)
        ShotImage.generation.bump(assetID: assetID)

        XCTAssertNotEqual(ShotImage.generation.value(for: assetID), beforeAffected,
                          "세대를 올렸는데 그 assetID 의 값이 그대로다 — .task(id:) 가 다시 안 돈다")
        XCTAssertEqual(ShotImage.generation.value(for: other), beforeOther,
                       "다른 assetID 의 세대까지 같이 올랐다 — 영향받은 것만 올라야 한다")

        let retried = await ShotImage.warm(m, maxPixel: 100)
        XCTAssertNotNil(retried, "세대가 올라 다시 요청했는데도 실패했다")
        XCTAssertEqual(source.calls(assetID), 2, "재요청이 실제로 사진 앱까지 닿지 않았다")
    }

    /// 실패 → 재시도 스케줄을 따라가며 몇 번째에 성공하는지, 끝까지 실패하면 몇 번 불렸는지.
    func testRetrySchedule() async {
        let tinyDelays: [UInt64] = [1_000_000, 1_000_000, 1_000_000] // 1ms — 실제 2·5·15초 대신 테스트용 간격

        let succeedsThirdTry = "SCHED-OK-\(UUID().uuidString)"
        let alwaysFails = "SCHED-FAIL-\(UUID().uuidString)"
        let source = ScriptedAssetSource([
            succeedsThirdTry: [false, false, true],
            alwaysFails: [false, false, false, false],
        ])
        ShotImage.assetSource = source

        let ok = await ShotImage.warmWithRetry(moment(succeedsThirdTry), maxPixel: 100, delays: tinyDelays)
        XCTAssertNotNil(ok, "재시도 스케줄대로면 세 번째에는 성공해야 한다")
        XCTAssertEqual(source.calls(succeedsThirdTry), 3, "처음 1번 + 재시도 2번(성공 시점) 만큼만 불려야 한다")

        let fail = await ShotImage.warmWithRetry(moment(alwaysFails), maxPixel: 100, delays: tinyDelays)
        XCTAssertNil(fail, "끝까지 실패했는데 성공을 돌려줬다")
        XCTAssertEqual(source.calls(alwaysFails), 1 + tinyDelays.count, "처음 1번 + 재시도 스케줄 개수만큼 불려야 한다")
    }

    /// assetID 가 없으면(파일판) 재시도 자체를 하지 않는다 — 애초에 사진 앱에 있을 이유가 없다.
    func testNoAssetIDSkipsRetry() async {
        ShotImage.assetSource = ScriptedAssetSource([:])
        let m = Moment(capturedAt: Date(), colorHex: "#112233",
                       fileName: "no-such-file-\(UUID().uuidString).jpg", source: .app)
        let result = await ShotImage.warmWithRetry(m, maxPixel: 100, delays: [50_000_000, 50_000_000])
        XCTAssertNil(result)
    }

    /// 캐시에 이미 성공한 이미지가 있으면 재요청(=사진 앱 호출)을 아예 하지 않는다 — 깜빡임 없이 기존 걸 쓴다.
    func testCachedSuccessSkipsRequest() async {
        let assetID = "CACHED-\(UUID().uuidString)"
        let warmSource = ScriptedAssetSource([assetID: [true]])
        ShotImage.assetSource = warmSource
        let m = moment(assetID)
        let warmed = await ShotImage.warm(m, maxPixel: 100)
        XCTAssertNotNil(warmed, "미리 데우기가 실패해 테스트 전제를 만들 수 없다")

        let mustNotBeCalled = MustNotBeCalledSource()
        ShotImage.assetSource = mustNotBeCalled

        let result = await ShotImage.warmWithRetry(m, maxPixel: 100, delays: [50_000_000])
        XCTAssertNotNil(result, "캐시가 있는데도 nil 을 돌려줬다")
        XCTAssertEqual(mustNotBeCalled.calls, 0, "캐시가 있는데 사진 앱을 다시 불렀다")
    }
}
