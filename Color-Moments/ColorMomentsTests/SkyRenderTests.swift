import XCTest
@testable import ColorMoments

/// 스파이크 하늘 — 셰이더가 실제로 그려지고, 글자 자리에서 흰 64% 글자가 4.5:1 을 지키는지.
@MainActor
final class SkyRenderTests: XCTestCase {
    func testEverySkyKeepsTextContrast() throws {
        let sizes: [(SkyQuality, CGSize)] = [(.hero, CGSize(width: 354, height: 232)), (.card, CGSize(width: 354, height: 96))]
        for scene in SkyScene.allCases {
            for (q, size) in sizes {
                let frame = SkyFrame(scene: scene, quality: q, size: size)
                let out = try XCTUnwrap(SkySnapshot.image(frame, scale: 2, t: SceneArt.stillPhase), "\(scene) \(q)")
                let c = SkyDump.contrast(out.image, frame.textRects, size)
                XCTAssertGreaterThanOrEqual(c, 4.5, "\(scene.name) \(q.rawValue)")
            }
        }
    }
}
