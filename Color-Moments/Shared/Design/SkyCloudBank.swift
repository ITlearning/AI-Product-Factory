import CoreGraphics
import Metal
import QuartzCore

/// 구운 구름 판 — 장면마다 하늘 한 조각을 hero 보다 촘촘히 한 번 굽고(앱 실행 중 캐시), 목록 카드·중·하 단계 히어로가
/// 자기 창 자리에서 잘라 바람 쪽으로 흘린다. 모양 시각이 다른 두 장을 천천히 섞어 구름 모양도 아주 느리게 바뀐다.
final class SkyCloudBank: @unchecked Sendable {
    static let shared = SkyCloudBank()
    /// 판 번호 — 구름 셰이더·층 값을 바꾸면 올린다. 바뀌면 다음 그림부터 새로 굽는다.
    nonisolated(unsafe) static var version = 1
    /// 두 장의 모양 시각 차이(초)와 한 번 오가는 주기(초).
    static let keyframeGap = 40.0
    static let morphPeriod = 90.0
    /// 판 하나를 몇 줄로 나눠 굽는가 — 움직이는 화면은 한 프레임에 한 줄씩.
    static let strips = 10

    enum Shape: Hashable, Sendable {
        /// 카드·히어로 — 폭 768 × 높이 400pt
        case band
        /// 전체 화면 — 폭 800 × 높이 900pt
        case tall

        var sizePt: CGSize { self == .band ? CGSize(width: 768, height: 400) : CGSize(width: 800, height: 900) }
        var pxPerPt: Double { self == .band ? 1.25 : 1.0 }
        var pixels: (w: Int, h: Int) { (Int(sizePt.width * pxPerPt), Int(sizePt.height * pxPerPt)) }
        /// 같은 축척의 대표 화면 — 빛의 방향을 여기서 빌린다.
        var reference: CGSize { self == .band ? CGSize(width: 354, height: 232) : CGSize(width: 393, height: 852) }

        static func fitting(_ size: CGSize) -> Shape { size.height <= 400 && size.width <= 768 ? .band : .tall }
    }

    struct Key: Hashable, Sendable {
        var scene: SkyScene
        var shape: Shape
        var version: Int
    }

    final class Plate {
        let key: Key
        let frames: [MTLTexture]
        fileprivate(set) var done = 0
        fileprivate(set) var readyAt: Double?
        fileprivate var lastUse: Double

        init(key: Key, frames: [MTLTexture], now: Double) {
            self.key = key
            self.frames = frames
            lastUse = now
        }

        var total: Int { SkyCloudBank.strips * frames.count }
        var complete: Bool { done >= total }
        var bytes: Int { frames.reduce(0) { $0 + $1.width * $1.height * 8 } }
    }

    private let lock = NSLock()
    private var plates: [Key: Plate] = [:]
    private var lastLiveStrip = -1.0
    /// 메모리 상한 — 넘으면 오래 안 쓴 판부터 버린다.
    var capBytes = 40 << 20
    /// 지금까지 구운 줄 수(계측·테스트).
    private(set) var stripsBaked = 0

    var bytes: Int { lock.lock(); defer { lock.unlock() }; return plates.values.reduce(0) { $0 + $1.bytes } }
    var count: Int { lock.lock(); defer { lock.unlock() }; return plates.count }

    func removeAll() { lock.lock(); plates = [:]; lock.unlock() }

    func plate(_ scene: SkyScene, _ shape: Shape, device: MTLDevice, now: Double = CACurrentMediaTime()) -> Plate? {
        lock.lock(); defer { lock.unlock() }
        let key = Key(scene: scene, shape: shape, version: Self.version)
        if let p = plates[key] { p.lastUse = now; return p }
        plates = plates.filter { $0.key.version == Self.version }
        let (w, h) = shape.pixels
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: SkyGPU.format, width: w, height: h, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .private
        let frames = (0..<2).compactMap { _ in device.makeTexture(descriptor: d) }
        guard frames.count == 2 else { return nil }
        let p = Plate(key: key, frames: frames, now: now)
        plates[key] = p
        var total = plates.values.reduce(0) { $0 + $1.bytes }
        for old in plates.values.sorted(by: { $0.lastUse < $1.lastUse }) where total > capBytes && old !== p {
            plates[old.key] = nil
            total -= old.bytes
        }
        return p
    }

    /// 덜 구운 판을 이어 굽는다. all 이면 남은 줄 전부(정지 그림), 아니면 앱 전체에서 한 프레임(1/60초)에 한 줄.
    func advance(_ p: Plate, cb: MTLCommandBuffer, gpu: SkyGPU, all: Bool, now: Double = CACurrentMediaTime()) {
        lock.lock()
        var todo: [Int] = []
        if all {
            todo = Array(p.done..<p.total)
        } else if !p.complete, now - lastLiveStrip >= 1.0 / 60 {
            todo = [p.done]
            lastLiveStrip = now
        }
        p.done += todo.count
        stripsBaked += todo.count
        if p.complete, p.readyAt == nil { p.readyAt = all ? -.infinity : now }
        lock.unlock()
        for i in todo { encodeStrip(i, of: p, cb: cb, gpu: gpu) }
    }

    /// 구운 판의 불투명도 — 막 다 구워진 판은 0.6초에 걸쳐 나타난다.
    func opacity(_ p: Plate, now: Double = CACurrentMediaTime()) -> Float {
        lock.lock(); defer { lock.unlock() }
        guard let r = p.readyAt else { return 0 }
        return Float(min(max((now - r) / 0.6, 0), 1))
    }

    private func encodeStrip(_ i: Int, of p: Plate, cb: MTLCommandBuffer, gpu: SkyGPU) {
        let k = i / Self.strips, row = i % Self.strips
        let tex = p.frames[k]
        let rp = MTLRenderPassDescriptor()
        rp.colorAttachments[0].texture = tex
        rp.colorAttachments[0].loadAction = .load
        rp.colorAttachments[0].storeAction = .store
        guard let e = cb.makeRenderCommandEncoder(descriptor: rp) else { return }
        let h = tex.height, y0 = h * row / Self.strips, y1 = h * (row + 1) / Self.strips
        e.setScissorRect(MTLScissorRect(x: 0, y: y0, width: tex.width, height: y1 - y0))
        e.setRenderPipelineState(gpu.cloudBake)
        let floats = Self.uniforms(p.key, keyframe: k, pixels: CGSize(width: tex.width, height: tex.height)).floats
        floats.withUnsafeBytes { e.setFragmentBytes($0.baseAddress!, length: $0.count, index: 0) }
        e.setFragmentTexture(gpu.noise, index: 0)
        e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        e.endEncoding()
    }

    /// 굽기 무게 — 「최상」 히어로보다 촘촘하다(한 번만 그리니까).
    static let bakeBudget: SIMD4<Float> = [32, 5, 1, 14]

    static func uniforms(_ key: Key, keyframe: Int, pixels: CGSize) -> SkyUniforms {
        let size = key.shape.sizePt
        let frame = SkyFrame(scene: key.scene, quality: .hero, size: size, texts: .none)
        let budget = SkyBudget(.hero, tier: .ultra, still: true)
        var u = frame.uniforms(pixels: pixels, t: Double(keyframe) * keyframeGap, headroom: 1, tilt: .zero, frameIndex: 0,
                               rainCount: 0, budget: budget, meteor: nil)
        u.quality = bakeBudget
        let l = light(key.scene, key.shape)
        u.light = [Float(l.x), Float(l.y), 0, 0]
        u.extra.x = 0
        u.tone.y = 0
        u.win = [0, 0, 0, 2]
        return u
    }

    /// 판 위 빛 — 대표 화면에서 해·달이 가운데로부터 놓인 방향으로, 낮은 150pt(구름 뒤 조금 비스듬히)·밤은 520pt(옆에서 비껴 어둑하게).
    static func light(_ scene: SkyScene, _ shape: Shape) -> CGPoint {
        let ref = SkyFrame(scene: scene, quality: .hero, size: shape.reference, texts: .none).light.center
        let dx = ref.x - shape.reference.width / 2, dy = ref.y - shape.reference.height / 2
        let len = max(hypot(dx, dy), 1e-3)
        let reach: CGFloat = scene.isNight ? 520 : 150
        return CGPoint(x: dx / len * reach, y: dy / len * reach)
    }

    /// 판 안 창 자리(pt) — 가로는 흐름만큼 밀고 판 폭으로 돈다, 세로는 판 안에 들게.
    static func window(_ origin: CGPoint, size: CGSize, shape: Shape, flow: Double, t: Double) -> CGPoint {
        let s = shape.sizePt
        var x = (Double(origin.x) - flow * t).truncatingRemainder(dividingBy: Double(s.width))
        if x < 0 { x += Double(s.width) }
        let room = Double(s.height - size.height)
        var y = room > 0 ? Double(origin.y).truncatingRemainder(dividingBy: room) : 0
        if y < 0 { y += room }
        return CGPoint(x: x, y: y)
    }

    /// 두 장 섞는 값 — 0 에서 1 로 갔다가 돌아온다.
    static func morph(_ t: Double) -> Float { Float(0.5 - 0.5 * cos(2 * .pi * t / morphPeriod)) }
}
