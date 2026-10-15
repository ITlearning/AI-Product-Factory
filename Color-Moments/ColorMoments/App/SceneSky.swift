import MetalKit
import SwiftUI

/// 카드 배경 하나 — 하늘이 있는 장면(SkyScene.of)은 셰이더 하늘, 없으면 SceneView.
/// 움직일 때만 SkyView(MTKView)를 띄우고, 멈춘 동안(화면 밖·다른 칸·동작 줄이기)은 구운 한 장(SkyStills)을 깐다.
struct SceneSky: View {
    let kind: SceneKind
    let quality: SkyQuality
    var animating = false
    var tilts = false
    /// SceneView 로 그릴 때만 — 셰이더 하늘엔 사진 색 섞기가 아직 없다.
    var tintHex: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            if let sky = SkyScene.of(kind) {
                let texts = SkyTexts.card(geo.size)
                if animating, !reduceMotion {
                    SkyView(sky, quality: quality, animating: true, texts: texts, tilts: tilts)
                } else if let still = SkyStills.shared.image(sky, quality: quality, size: geo.size, scale: displayScale) {
                    Image(decorative: still, scale: displayScale).resizable()
                } else {
                    SkyView(sky, quality: quality, animating: false, texts: texts)
                }
            } else {
                SceneView(kind, style: .wash, animating: animating,
                          frameInterval: quality == .card ? SceneView.cardFrameInterval : SceneView.heroFrameInterval,
                          tintHex: tintHex)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 멈춘 하늘 한 장 — 장면·쓰임새·크기·배율·달 나이(날)마다 한 번 굽고 메모리에 둔다.
final class SkyStills: @unchecked Sendable {
    static let shared = SkyStills()

    private let cache = NSCache<NSString, CGImage>()
    private let tier: SkyTier

    init() {
        cache.totalCostLimit = 24 << 20
        let device = MTLCreateSystemDefaultDevice()
        tier = device.map { SkyTier.detect($0, maxFPS: UIScreen.main.maximumFramesPerSecond) } ?? .mid
    }

    static func key(_ scene: SkyScene, quality: SkyQuality, size: CGSize, scale: CGFloat, moonDay: Int) -> String {
        "\(scene.key)-\(quality.rawValue)-\(Int(size.width.rounded()))x\(Int(size.height.rounded()))@\(Int(scale))-m\(scene.showsMoon ? moonDay : 0)"
    }

    func image(_ scene: SkyScene, quality: SkyQuality, size: CGSize, scale: CGFloat, now: Date = Date()) -> CGImage? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let age = Celestial.moonAge(at: now)
        let k = Self.key(scene, quality: quality, size: size, scale: scale, moonDay: Int(age)) as NSString
        if let hit = cache.object(forKey: k) { return hit }
        let frame = SkyFrame(scene: scene, quality: quality, size: size, texts: SkyTexts.card(size), moonAge: age)
        guard let img = SkySnapshot.image(frame, scale: scale, t: SceneArt.stillPhase, tier: tier)?.image else { return nil }
        cache.setObject(img, forKey: k, cost: img.bytesPerRow * img.height)
        return img
    }
}
