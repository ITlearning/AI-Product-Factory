import MetalKit
import SwiftUI

/// 카드 배경 하나 — 하늘이 있는 장면(SkyScene.of)은 셰이더 하늘, 없으면 SceneView.
/// 움직일 때만 SkyView(MTKView)를 띄우고, 멈춘 동안(화면 밖·다른 칸·동작 줄이기)은 구운 한 장(SkyStills)을 깐다.
struct SceneSky: View {
    let kind: SceneKind
    let quality: SkyQuality
    var animating = false
    var tilts = false
    /// 카드마다 큰 구름층의 다른 조각을 본다(SkyFrame.window).
    var seed: Int?
    /// SceneView 로 그릴 때만 — 셰이더 하늘엔 사진 색 섞기가 아직 없다.
    var tintHex: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            if let sky = SkyScene.of(kind) {
                let texts = SkyTexts.card(geo.size)
                if animating, !reduceMotion {
                    SkyView(sky, quality: quality, animating: true, texts: texts, tilts: tilts, seed: seed)
                } else if let still = SkyStills.shared.image(sky, quality: quality, size: geo.size, scale: displayScale, seed: seed) {
                    Image(decorative: still, scale: displayScale).resizable()
                } else {
                    SkyView(sky, quality: quality, animating: false, texts: texts, seed: seed)
                }
            } else {
                SceneView(kind, style: .wash, animating: animating,
                          frameInterval: quality == .card ? SceneView.cardFrameInterval : SceneView.heroFrameInterval,
                          tintHex: tintHex)
            }
        }
        .accessibilityHidden(true)
    }

    /// 실행마다 같아야 한다 — String.hashValue 는 실행마다 바뀐다.
    static func seed(_ text: String) -> Int {
        var h: UInt32 = 2_166_136_261
        for b in text.utf8 { h = (h ^ UInt32(b)) &* 16_777_619 }
        return Int(h & 0x7fff_ffff)
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

    static func key(_ scene: SkyScene, quality: SkyQuality, size: CGSize, scale: CGFloat, moonDay: Int, seed: Int? = nil) -> String {
        "\(scene.key)-\(quality.rawValue)-\(Int(size.width.rounded()))x\(Int(size.height.rounded()))@\(Int(scale))-m\(scene.showsMoon ? moonDay : 0)-s\(seed ?? 0)"
    }

    func image(_ scene: SkyScene, quality: SkyQuality, size: CGSize, scale: CGFloat, seed: Int? = nil, now: Date = Date()) -> CGImage? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let age = Celestial.moonAge(at: now)
        let k = Self.key(scene, quality: quality, size: size, scale: scale, moonDay: Int(age), seed: seed) as NSString
        if let hit = cache.object(forKey: k) { return hit }
        let frame = SkyFrame(scene: scene, quality: quality, size: size, texts: SkyTexts.card(size), moonAge: age,
                             window: seed.map(SkyFrame.window(seed:)) ?? .zero)
        guard let img = SkySnapshot.image(frame, scale: scale, t: SceneArt.stillPhase, tier: tier)?.image else { return nil }
        cache.setObject(img, forKey: k, cost: img.bytesPerRow * img.height)
        return img
    }
}
