import MetalKit
import SwiftUI

/// 카드 배경 하나 — 하늘이 있는 장면(SkyScene.of)은 셰이더 하늘, 없으면 SceneView.
/// 구운 한 장(SkyStills)을 늘 깔고, 움직일 때만 그 위에 SkyView(풀에서 빌린 MTKView)를 띄운다 — 같은 t·같은 판이라 이어진다.
/// 스크롤 중(SkyScroll.moving)엔 움직이지 않는다 — 스크롤하는 동안 MTKView 를 만들지 않게. 펼친 말(live)은 예외.
/// 한 장은 메인 밖에서 굽는다 — 스크롤 중 새 카드가 들어올 때 메인이 막히지 않게. 굽는 동안은 같은 장면의 다른 카드 한 장.
struct SceneSky: View {
    let kind: SceneKind
    let quality: SkyQuality
    var animating = false
    var tilts = false
    /// 카드마다 큰 구름층의 다른 조각을 본다(SkyFrame.window).
    var seed: Int?
    /// SceneView 로 그릴 때만 — 셰이더 하늘엔 사진 색 섞기가 아직 없다.
    var tintHex: String?
    /// 스크롤 없는 곳(펼친 말) — 상·최상은 구름을 실시간으로. 스크롤하는 곳은 모든 단계 구운 판.
    var live: Bool?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var baked = 0

    var body: some View {
        let _ = SkyStats.shared.count { $0.bodies += 1 }
        GeometryReader { geo in
            if let sky = SkyScene.of(kind) {
                let texts = SkyTexts.card(geo.size)
                let frozen = SkyScroll.shared.frozen
                let moves = !frozen && animating && !reduceMotion && (live == true || !SkyScroll.shared.holds)
                let still = still(sky, geo.size)
                ZStack {
                    if let still {
                        Image(decorative: still, scale: displayScale).resizable()
                    }
                    if moves {
                        SkyView(sky, quality: quality, animating: true, texts: texts, tilts: tilts, seed: seed, live: live)
                    } else if still == nil, !frozen {
                        SkyView(sky, quality: quality, animating: false, texts: texts, seed: seed, live: live)
                    }
                }
            } else {
                SceneView(kind, style: .wash, animating: animating,
                          frameInterval: quality == .card ? SceneView.cardFrameInterval : SceneView.heroFrameInterval,
                          tintHex: tintHex)
            }
        }
        .accessibilityHidden(true)
    }

    private func still(_ sky: SkyScene, _ size: CGSize) -> CGImage? {
        _ = baked
        let stills = SkyStills.shared
        if let hit = stills.cached(sky, quality: quality, size: size, scale: displayScale, seed: seed) {
            SkyStats.shared.count { $0.stillHits += 1 }
            return hit
        }
        SkyStats.shared.count { $0.stillMisses += 1 }
        stills.request(sky, quality: quality, size: size, scale: displayScale, seed: seed) { baked += 1 }
        return stills.cached(sky, quality: quality, size: size, scale: displayScale, seed: nil)
    }

    /// 실행마다 같아야 한다 — String.hashValue 는 실행마다 바뀐다.
    static func seed(_ text: String) -> Int {
        var h: UInt32 = 2_166_136_261
        for b in text.utf8 { h = (h ^ UInt32(b)) &* 16_777_619 }
        return Int(h & 0x7fff_ffff)
    }
}

/// 멈춘 하늘 한 장 — 장면·쓰임새·크기·배율·달 나이(날)마다 한 번 굽고 메모리에 둔다.
final class SkyStills: NSObject, NSCacheDelegate, @unchecked Sendable {
    static let shared = SkyStills()

    private let cache = NSCache<NSString, CGImage>()
    private let tier: SkyTier

    private let queue = DispatchQueue(label: "mongdol.sky.stills", qos: .userInitiated)
    private let lock = NSLock()
    private var pending: [String: [@MainActor () -> Void]] = [:]
    private var held = (count: 0, bytes: 0)

    /// 캐시에 든 정지 그림 장수·바이트(CPU 메모리, 계측).
    var memory: (count: Int, bytes: Int) { lock.lock(); defer { lock.unlock() }; return held }

    override init() {
        let device = MTLCreateSystemDefaultDevice()
        tier = device.map { SkyTier.detect($0, maxFPS: UIScreen.main.maximumFramesPerSecond) } ?? .mid
        super.init()
        cache.totalCostLimit = 64 << 20
        cache.delegate = self
    }

    static func key(_ scene: SkyScene, quality: SkyQuality, size: CGSize, scale: CGFloat, moonDay: Int, seed: Int? = nil,
                    tier: SkyTier? = nil) -> String {
        "\(scene.key)-\(quality.rawValue)-\(Int(size.width.rounded()))x\(Int(size.height.rounded()))@\(Int(scale))-m\(scene.showsMoon ? moonDay : 0)-s\(seed ?? 0)-t\(tier?.rawValue ?? -1)"
    }

    /// 움직이는 하늘과 같은 판 — 디버그로 단계를 바꾸면 한 장도 그 단계로.
    private var currentTier: SkyTier { SkyDebug.tier ?? tier }

    func cached(_ scene: SkyScene, quality: SkyQuality, size: CGSize, scale: CGFloat, seed: Int? = nil, now: Date = Date()) -> CGImage? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let k = Self.key(scene, quality: quality, size: size, scale: scale, moonDay: Int(Celestial.moonAge(at: now)), seed: seed, tier: currentTier)
        return cache.object(forKey: k as NSString)
    }

    /// 메인 밖에서 굽고 다 되면 메인에서 done. 같은 한 장을 여럿이 부르면 한 번만 굽는다.
    func request(_ scene: SkyScene, quality: SkyQuality, size: CGSize, scale: CGFloat, seed: Int? = nil,
                 done: @escaping @MainActor () -> Void) {
        guard size.width >= 1, size.height >= 1 else { return }
        let k = Self.key(scene, quality: quality, size: size, scale: scale, moonDay: Int(Celestial.moonAge(at: Date())), seed: seed, tier: currentTier)
        lock.lock()
        let first = pending[k] == nil
        pending[k, default: []].append(done)
        lock.unlock()
        guard first else { return }
        queue.async { [self] in
            _ = image(scene, quality: quality, size: size, scale: scale, seed: seed)
            lock.lock()
            let waiters = pending.removeValue(forKey: k) ?? []
            lock.unlock()
            DispatchQueue.main.async { waiters.forEach { $0() } }
        }
    }

    func image(_ scene: SkyScene, quality: SkyQuality, size: CGSize, scale: CGFloat, seed: Int? = nil, now: Date = Date()) -> CGImage? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let age = Celestial.moonAge(at: now)
        let tier = currentTier
        let k = Self.key(scene, quality: quality, size: size, scale: scale, moonDay: Int(age), seed: seed, tier: tier) as NSString
        if let hit = cache.object(forKey: k) { return hit }
        let start = CACurrentMediaTime()
        defer {
            let ms = (CACurrentMediaTime() - start) * 1000
            SkyStats.shared.count { $0.stills += 1; $0.stillMs += ms; $0.worstStillMs = max($0.worstStillMs, ms) }
        }
        let frame = SkyFrame(scene: scene, quality: quality, size: size, texts: SkyTexts.card(size), moonAge: age,
                             window: seed.map(SkyFrame.window(seed:)) ?? .zero)
        guard let img = SkySnapshot.image(frame, scale: scale, t: SceneArt.stillPhase, tier: tier)?.image else { return nil }
        let cost = img.bytesPerRow * img.height
        lock.lock(); held.count += 1; held.bytes += cost; lock.unlock()
        cache.setObject(img, forKey: k, cost: cost)
        return img
    }

    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        guard CFGetTypeID(obj as CFTypeRef) == CGImage.typeID else { return }
        let img = obj as! CGImage
        lock.lock(); held.count -= 1; held.bytes -= img.bytesPerRow * img.height; lock.unlock()
    }
}
