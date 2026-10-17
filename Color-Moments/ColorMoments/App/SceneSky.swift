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
                        Image(decorative: still, scale: quality.renderScale(displayScale)).resizable()
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

    /// 움직이는 카드와 같은 배율(카드 2/3)로 굽는다 — 이어질 때 선명도가 바뀌지 않게.
    private func still(_ sky: SkyScene, _ size: CGSize) -> CGImage? {
        _ = baked
        let stills = SkyStills.shared
        let scale = quality.renderScale(displayScale)
        if let hit = stills.cached(sky, quality: quality, size: size, scale: scale, seed: seed) {
            SkyStats.shared.count { $0.stillHits += 1 }
            return hit
        }
        SkyStats.shared.count { $0.stillMisses += 1 }
        stills.request(sky, quality: quality, size: size, scale: scale, seed: seed) { baked += 1 }
        return stills.cached(sky, quality: quality, size: size, scale: scale, seed: nil)
    }

    /// 실행마다 같아야 한다 — String.hashValue 는 실행마다 바뀐다.
    static func seed(_ text: String) -> Int {
        var h: UInt32 = 2_166_136_261
        for b in text.utf8 { h = (h ^ UInt32(b)) &* 16_777_619 }
        return Int(h & 0x7fff_ffff)
    }
}

/// 멈춘 하늘 한 장 — 장면·쓰임새·크기·배율·달 나이(날)마다 한 번 굽고 메모리에 둔다.
/// 상한은 카드 크기로 정하고(SkyStills.cap), 넘치면 오래 안 본 것(화면에서 먼 카드)부터 버린다.
final class SkyStills: @unchecked Sendable {
    static let shared = SkyStills()

    private let tier: SkyTier
    private let capBytes: Int

    private let queue = DispatchQueue(label: "mongdol.sky.stills", qos: .userInitiated)
    private let lock = NSLock()
    private var pending: [String: [@MainActor () -> Void]] = [:]
    private var entries: [String: (image: CGImage, cost: Int, used: UInt64)] = [:]
    private var tick: UInt64 = 0
    private var held = (count: 0, bytes: 0)
    private var warning: NSObjectProtocol?

    /// 캐시에 든 정지 그림 장수·바이트(CPU 메모리, 계측).
    var memory: (count: Int, bytes: Int) { lock.lock(); defer { lock.unlock() }; return held }

    init(capBytes: Int? = nil) {
        let device = MTLCreateSystemDefaultDevice()
        tier = device.map { SkyTier.detect($0, maxFPS: UIScreen.main.maximumFramesPerSecond) } ?? .mid
        self.capBytes = capBytes ?? Self.cap(width: UIScreen.main.bounds.width, screen: UIScreen.main.scale)
        warning = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil,
                                                         queue: nil) { [weak self] _ in self?.removeAll() }
    }

    /// 「말」 칸 두 화면 남짓 — 줄 카드 48장(2/3 배율) + 오늘의 한 장 크기 4장.
    static func cap(width: CGFloat, screen: CGFloat) -> Int {
        func bytes(_ h: CGFloat, _ q: SkyQuality) -> Int {
            let s = q.renderScale(screen)
            return Int((width * s).rounded()) * Int((h * s).rounded()) * 4
        }
        return 48 * bytes(96, .card) + 4 * bytes(232, .hero)
    }

    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        entries = [:]
        held = (0, 0)
    }

    static func key(_ scene: SkyScene, quality: SkyQuality, size: CGSize, scale: CGFloat, moonDay: Int, seed: Int? = nil,
                    tier: SkyTier? = nil) -> String {
        "\(scene.key)-\(quality.rawValue)-\(Int(size.width.rounded()))x\(Int(size.height.rounded()))@\(Int((scale * 100).rounded()))-m\(scene.showsMoon ? moonDay : 0)-s\(seed ?? 0)-t\(tier?.rawValue ?? -1)"
    }

    private func lookup(_ k: String) -> CGImage? {
        lock.lock(); defer { lock.unlock() }
        guard let e = entries[k] else { return nil }
        tick += 1
        entries[k]?.used = tick
        return e.image
    }

    private func store(_ img: CGImage, _ k: String) {
        let cost = img.bytesPerRow * img.height
        lock.lock(); defer { lock.unlock() }
        tick += 1
        if let old = entries[k] { held.count -= 1; held.bytes -= old.cost }
        entries[k] = (img, cost, tick)
        held.count += 1; held.bytes += cost
        guard held.bytes > capBytes else { return }
        for (key, e) in entries.sorted(by: { $0.value.used < $1.value.used }) where held.bytes > capBytes && key != k {
            entries[key] = nil
            held.count -= 1; held.bytes -= e.cost
        }
    }

    /// 움직이는 하늘과 같은 판 — 디버그로 단계를 바꾸면 한 장도 그 단계로.
    private var currentTier: SkyTier { SkyDebug.tier ?? tier }

    func cached(_ scene: SkyScene, quality: SkyQuality, size: CGSize, scale: CGFloat, seed: Int? = nil, now: Date = Date()) -> CGImage? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let k = Self.key(scene, quality: quality, size: size, scale: scale, moonDay: Int(Celestial.moonAge(at: now)), seed: seed, tier: currentTier)
        return lookup(k)
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
        let k = Self.key(scene, quality: quality, size: size, scale: scale, moonDay: Int(age), seed: seed, tier: tier)
        if let hit = lookup(k) { return hit }
        let start = CACurrentMediaTime()
        defer {
            let ms = (CACurrentMediaTime() - start) * 1000
            SkyStats.shared.count { $0.stills += 1; $0.stillMs += ms; $0.worstStillMs = max($0.worstStillMs, ms) }
        }
        let frame = SkyFrame(scene: scene, quality: quality, size: size, texts: SkyTexts.card(size), moonAge: age,
                             window: seed.map(SkyFrame.window(seed:)) ?? .zero)
        guard let img = SkySnapshot.image(frame, scale: scale, t: SceneArt.stillPhase, tier: tier)?.image else { return nil }
        store(img, k)
        return img
    }
}
