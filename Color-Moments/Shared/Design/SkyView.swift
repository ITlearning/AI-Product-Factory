import CoreMotion
#if canImport(MetalFX)
import MetalFX
#endif
import MetalKit
import SwiftUI

/// 스파이크 — Apple 날씨 같은 하늘. 판정 뒤에 SceneView 를 갈아끼운다.
public enum SkyScene: Int, CaseIterable, Identifiable, Sendable {
    case nightCloudy, clearDay, rain, clearNight

    public var id: Int { rawValue }

    public var name: String {
        switch self {
        case .nightCloudy: "밤 흐림"
        case .clearDay: "맑은 낮"
        case .rain: "비"
        case .clearNight: "맑은 밤"
        }
    }

    /// 지금 장면에서 가장 가까운 것 — 나란히 비교할 때.
    public var legacy: SceneKind {
        switch self {
        case .nightCloudy, .clearNight: .moon
        case .clearDay: .sun
        case .rain: .rain
        }
    }

    var isNight: Bool { self == .nightCloudy || self == .clearNight }

    /// 가까운 구름층이 흐르는 속도(pt/초, 음수 = 왼쪽). 셰이더 layerFor 의 drift / scale × WORLD.
    var cloudFlow: Float {
        switch self {
        case .nightCloudy: -0.0075 / 0.32 * 320
        case .rain: -0.014 / 0.36 * 320
        case .clearDay, .clearNight: 0
        }
    }
}

/// 품질 단계 — 화면 쓰임새. 기기 단계(SkyTier)와 곱해져 SkyBudget 이 된다.
public enum SkyQuality: String, CaseIterable, Identifiable, Sendable {
    /// 전체 화면 하늘
    case full
    /// 오늘의 한 장
    case hero
    /// 목록 카드(30fps, 화면 밖은 멈춤)
    case card

    public var id: String { rawValue }

    var cloudScale: Double { switch self { case .full: 0.5; case .hero: 0.5; case .card: 0.34 } }
    var cloudSteps: Int { switch self { case .full: 26; case .hero: 24; case .card: 12 } }
    var farSteps: Int { switch self { case .full: 12; case .hero: 12; case .card: 6 } }
    var lightSteps: Int { switch self { case .full: 6; case .hero: 5; case .card: 3 } }
    var detail: Bool { self != .card }
    var rainCap: Int { switch self { case .full: 6000; case .hero: 2400; case .card: 700 } }
    var bloomLevels: Int { switch self { case .full: 6; case .hero: 5; case .card: 4 } }
    var cirrusOctaves: Int { self == .card ? 4 : 5 }
    var raySamples: Int { switch self { case .full: 48; case .hero: 32; case .card: 0 } }
    public var fps: Int { self == .card ? 30 : 120 }
}

/// 기기 단계 — GPU 세대 × 화면 최대 주사율로 판정한다(칩 이름은 보지 않는다).
public enum SkyTier: Int, CaseIterable, Identifiable, Comparable, Sendable {
    /// A12·A13(apple6 이하)
    case low
    /// apple7·apple8 + 60Hz (iPhone 12·13·14)
    case mid
    /// apple8 + 120Hz (13 Pro·14 Pro), apple9 + 60Hz
    case high
    /// apple9 이상 + 120Hz (15 Pro·16 Pro)
    case ultra

    public var id: Int { rawValue }
    public static func < (a: SkyTier, b: SkyTier) -> Bool { a.rawValue < b.rawValue }

    public var name: String {
        switch self {
        case .low: "하"
        case .mid: "중"
        case .high: "상"
        case .ultra: "최상"
        }
    }

    public static func detect(_ device: MTLDevice, maxFPS: Int) -> SkyTier {
        let pro = maxFPS >= 120
        if device.supportsFamily(.apple9) { return pro ? .ultra : .high }
        if device.supportsFamily(.apple8) { return pro ? .high : .mid }
        if device.supportsFamily(.apple7) { return .mid }
        return .low
    }

    var lower: SkyTier { SkyTier(rawValue: max(rawValue - 1, 0)) ?? .low }
}

/// 한 장면을 그리는 데 쓰는 무게 전부.
public struct SkyBudget: Equatable, Sendable {
    public var tier: SkyTier
    public var hot = false
    public var cloudScale: Double
    public var cloudSteps: Int
    public var farSteps: Int
    public var lightSteps: Int
    public var detail: Bool
    public var raySamples: Int
    public var bloomLevels: Int
    public var starLayers: Int
    /// 맑은 낮 새털구름 fbm 옥타브(결 몸통·실 각각).
    public var cirrusOctaves: Int
    /// 햇무리가 새털구름 따라 얼룩지게(값 노이즈 한 번).
    public var haloPatches: Bool
    /// 구름 레이마칭을 몇 프레임에 한 번 할지. 0 이면 매 프레임 그 시각 그대로(정지 그림).
    public var cloudEvery: Int
    public var fps: Int
    /// MetalFX 로 구름을 이 배율까지 올린다(nil = 안 씀).
    public var upscaleTo: Double?

    public init(_ q: SkyQuality, tier: SkyTier, thermal: ProcessInfo.ThermalState = .nominal,
                lowPower: Bool = false, metalFX: Bool? = nil, still: Bool = false) {
        let hot = thermal == .serious || thermal == .critical
        let t = hot ? tier.lower : tier
        self.tier = t
        self.hot = hot
        let card = q == .card
        func steps(_ n: Int, _ k: Double) -> Int { max(Int((Double(n) * k).rounded()), 3) }
        switch t {
        case .ultra:
            cloudScale = q.cloudScale; cloudSteps = q.cloudSteps; farSteps = q.farSteps; lightSteps = q.lightSteps
            detail = q.detail; raySamples = q.raySamples; bloomLevels = q.bloomLevels; starLayers = 3
            cloudEvery = card ? 8 : 4; fps = q.fps
        case .high:
            cloudScale = q.cloudScale; cloudSteps = steps(q.cloudSteps, 0.85); farSteps = steps(q.farSteps, 0.85)
            lightSteps = q.lightSteps; detail = q.detail; raySamples = q.raySamples * 3 / 4
            bloomLevels = q.bloomLevels; starLayers = 3
            cloudEvery = card ? 10 : 6; fps = q.fps
        case .mid:
            cloudScale = q.cloudScale * 0.75; cloudSteps = steps(q.cloudSteps, 0.7); farSteps = steps(q.farSteps, 0.7)
            lightSteps = max(q.lightSteps - 1, 2); detail = q.detail; raySamples = q.raySamples / 2
            bloomLevels = q.bloomLevels; starLayers = 3
            cloudEvery = card ? 8 : 4; fps = min(q.fps, 60)
        case .low:
            cloudScale = q.cloudScale * 0.67; cloudSteps = steps(q.cloudSteps, 0.55); farSteps = 0
            lightSteps = 2; detail = false; raySamples = 0
            bloomLevels = max(q.bloomLevels - 1, 3); starLayers = 2
            cloudEvery = card ? 12 : 8; fps = min(q.fps, 60)
        }
        cirrusOctaves = max(q.cirrusOctaves - (t == .low ? 2 : (t == .mid ? 1 : 0)), 3)
        haloPatches = t != .low
        if hot { fps = 30 }
        if lowPower { fps = min(fps, 60) }
        let wantsFX = metalFX ?? (t == .mid || t == .low)
        upscaleTo = wantsFX && cloudScale < q.cloudScale ? q.cloudScale : nil
        if still { cloudEvery = 0 }
    }
}

/// 디버그 화면에서 실기기 비교용으로 바꾸는 값. 출시엔 모두 nil/기본.
public enum SkyDebug {
    nonisolated(unsafe) public static var tier: SkyTier?
    nonisolated(unsafe) public static var metalFX: Bool?
    nonisolated(unsafe) public static var moonAge: Double?
    nonisolated(unsafe) public static var moonScale: Double = 1
    nonisolated(unsafe) public static var frequentMeteors = false
}

/// 디버그 계측 — 그리는 쪽에서 쓰고 화면이 읽는다.
public final class SkyStats: @unchecked Sendable {
    public static let shared = SkyStats()
    private let lock = NSLock()
    private struct Row { var gpu = 0.0; var renders: [Double] = []; var frames: [Double] = []; var label = "" }
    private var rows: [SkyQuality: Row] = [:]

    func frame(_ q: SkyQuality, gpuMs: Double) {
        lock.lock(); defer { lock.unlock() }
        let g = rows[q, default: Row()].gpu
        rows[q, default: Row()].gpu = g == 0 ? gpuMs : g * 0.9 + gpuMs * 0.1
    }

    func tick(_ q: SkyQuality, now: Double, cloudRendered: Int, label: String) {
        lock.lock(); defer { lock.unlock() }
        var r = rows[q, default: Row()]
        r.frames.append(now)
        for _ in 0..<cloudRendered { r.renders.append(now) }
        r.frames.removeAll { now - $0 > 1 }
        r.renders.removeAll { now - $0 > 1 }
        r.label = label
        rows[q] = r
    }

    /// 화면 쓰임새마다 한 줄 — 같은 쓰임새의 뷰가 여럿이면 합쳐 센다.
    public var summary: String {
        lock.lock(); defer { lock.unlock() }
        let now = CACurrentMediaTime()
        return SkyQuality.allCases.compactMap { q in
            guard let r = rows[q], let last = r.frames.last, now - last < 1 else { return nil }
            return String(format: "%@ %@ · GPU %.2fms · %dfps · 구름 %d회/초", q.rawValue, r.label, r.gpu, r.frames.count, r.renders.count)
        }.joined(separator: "\n")
    }
}

/// 별똥별 — 시간 t 만으로 정해진다(멈춤·이어가기에도 같은 자리).
public struct SkyMeteor: Equatable, Sendable {
    public var head: CGPoint
    public var direction: CGVector
    public var tail: CGFloat
    public var width: CGFloat
    public var alpha: CGFloat

    /// 슬롯마다 한 번 — 평균 every 초, 실제 간격은 every ± 0.4·every.
    public static func at(t: Double, size: CGSize, every: Double = 25) -> SkyMeteor? {
        let slot = (t / every).rounded(.down)
        func h(_ salt: UInt64) -> Double {
            var z = UInt64(bitPattern: Int64(slot)) &+ salt &* 0x9E37_79B9_7F4A_7C15
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return Double(z >> 11) / Double(1 << 53)
        }
        let start = slot * every + every * (0.3 + 0.4 * h(1))
        let duration = 0.37 * (0.85 + 0.4 * h(2))
        let f = (t - start) / duration
        guard f >= 0, f <= 1 else { return nil }
        let w = size.width, hgt = size.height
        let angle = (8 + 10 * h(3)) * .pi / 180
        let dir = CGVector(dx: -cos(angle), dy: sin(angle))
        let origin = CGPoint(x: w * (0.78 + 0.22 * h(4)), y: hgt * (0.06 + 0.22 * h(5)))
        let travel = w * 0.6 * (0.85 + 0.3 * h(6))
        let g = f * (1.15 - 0.15 * f)
        let head = CGPoint(x: origin.x + dir.dx * travel * g, y: origin.y + dir.dy * travel * g)
        let grow = min(1, f / 0.35)
        let tail = w * 0.25 * (0.8 + 0.4 * h(7)) * grow * grow * (3 - 2 * grow)
        let fadeIn = min(1, f / 0.12), fadeOut = 1 - max(0, (f - 0.6) / 0.4)
        let alpha = (0.7 + 0.3 * h(8)) * fadeIn * fadeIn * (3 - 2 * fadeIn) * fadeOut * fadeOut * (3 - 2 * fadeOut)
        return SkyMeteor(head: head, direction: dir, tail: max(tail, 1), width: 0.55, alpha: alpha)
    }
}

/// 글자 자리 — 작은 글자(secondary 64%, 4.5:1)와 큰 말(명조 48 이상, primary 92%, 3:1)을 나눈다.
public struct SkyTexts: Equatable, Sendable {
    public var small: [CGRect]
    public var big: [CGRect]

    public init(small: [CGRect], big: [CGRect] = []) {
        self.small = small
        self.big = big
    }

    public static let none = SkyTexts(small: [])
    public var all: [CGRect] { small + big }

    /// 「말」 칸 카드와 같은 배치. 오늘의 한 장만 큰 말(명조 48)이 있다 — 뜻 두 줄(13pt)이 덩어리 아래 42pt.
    public static func card(_ size: CGSize) -> SkyTexts {
        let r = SceneArt.textRects(in: size)
        guard SceneArt.Frame(size).hero, r.count == 2 else { return SkyTexts(small: r) }
        let block = r[1], meaning: CGFloat = 42
        return SkyTexts(small: [r[0], CGRect(x: block.minX, y: block.maxY - meaning, width: block.width, height: meaning)],
                        big: [CGRect(x: block.minX, y: block.minY, width: block.width, height: block.height - meaning)])
    }
}

/// 셰이더 SkyU 와 같은 배치 — float4 × 18.
struct SkyUniforms {
    var res = SIMD4<Float>(repeating: 0)
    var view = SIMD4<Float>(repeating: 0)
    var light = SIMD4<Float>(repeating: 0)
    var quality = SIMD4<Float>(repeating: 0)
    var tone = SIMD4<Float>(repeating: 0)
    var parallax = SIMD4<Float>(repeating: 0)
    var rays = SIMD4<Float>(repeating: 0)
    var moon = SIMD4<Float>(repeating: 0)
    var meteor0 = SIMD4<Float>(repeating: 0)
    var meteor1 = SIMD4<Float>(repeating: 0)
    var blend = SIMD4<Float>(repeating: 0)
    var sun = SIMD4<Float>(repeating: 0)
    var caps = SIMD4<Float>(repeating: 0)
    var textBig = SIMD4<Float>(repeating: 0)
    var text: [SIMD4<Float>] = Array(repeating: .zero, count: 4)

    var floats: [SIMD4<Float>] { [res, view, light, quality, tone, parallax, rays, moon, meteor0, meteor1, blend, sun, caps, textBig] + text }
}

/// 장면·크기에서 정해지는 것(픽셀마다 같은 값).
public struct SkyFrame: Equatable {
    public var scene: SkyScene
    public var quality: SkyQuality
    public var size: CGSize
    public var texts: SkyTexts
    public var textRects: [CGRect] { texts.all }
    /// 마지막 삭에서 며칠(Celestial.moonAge). 0 삭 · 7.4 상현 · 14.8 보름 · 22.1 하현.
    public var moonAge: Double
    /// 달 크기 배수(디버그)
    public var moonScale: Double

    public init(scene: SkyScene, quality: SkyQuality, size: CGSize, texts: SkyTexts? = nil,
                moonAge: Double = 10, moonScale: Double = 1) {
        self.scene = scene
        self.quality = quality
        self.size = size
        self.texts = texts ?? SkyTexts.card(size)
        self.moonAge = moonAge
        self.moonScale = moonScale
    }

    /// 진짜 달은 하늘에서 작다 — 1차보다 0.78배.
    static let moonShrink: CGFloat = 0.78

    /// 해·달 자리(pt)와 반지름. 비는 위쪽 먼 곳의 흐린 빛(그리지 않음).
    var light: (center: CGPoint, radius: CGFloat, drawn: Bool) {
        let w = size.width, h = size.height, u = min(w, h)
        if scene == .rain { return (CGPoint(x: 0.5 * w, y: -2.2 * 320), 0, false) }
        let night = scene.isNight
        let m = Self.moonShrink * CGFloat(moonScale)
        if h > 1.3 * w {
            return night ? (CGPoint(x: 0.84 * w, y: 0.085 * h), 15 * m, true)
                         : (CGPoint(x: 0.78 * w, y: 0.025 * h), 8, true)
        }
        let f = SceneArt.Frame(size)
        if f.wide { return (CGPoint(x: f.pane.midX, y: night ? 0.42 * h : 0.12 * h), night ? 0.11 * u * m : 0.07 * u, true) }
        return night ? (CGPoint(x: w - 0.2 * u, y: 0.2 * u), 0.075 * u * m, true)
                     : (CGPoint(x: w - 0.2 * u, y: 0.07 * u), 0.036 * u, true)
    }

    /// 밝은 면 비율(0 삭 ~ 1 보름).
    var moonLit: Double { 0.5 - 0.5 * cos(moonAge / Celestial.synodicMonth * 2 * .pi) }

    /// 작은 글자 자리 위 하늘의 최대 상대 휘도 — 흰 64%(secondary) 글자가 4.5:1 을 넘게.
    static let textLuminanceCap: Float = 0.07
    /// 큰 말 자리 — 흰 92%(primary) 명조 48 이상이 3:1 을 넘게(맑은 낮만, 다른 장면은 작은 글자와 같게 둔다).
    static let bigTextLuminanceCap: Float = 0.24
    /// 맑은 낮 작은 글자 자리 — 밝은 하늘 위 작은 글자는 primary(92%)로 쓰고 4.5:1. secondary 로 4.5 를 내려면 하늘을 3배 넘게 눌러야 해서.
    static let dayTextLuminanceCap: Float = 0.155

    /// 작은 글자의 흰 불투명도 — 맑은 낮만 primary.
    public var smallTextAlpha: Double { scene == .clearDay ? Tone.primaryAlpha : Tone.secondaryAlpha }

    /// 22° 햇무리 반지름(pt) — 남극 화면에서 해부터 큰 숫자를 지나는 원(폭의 ≈0.65).
    var haloRadius: CGFloat {
        let f = SceneArt.Frame(size)
        return f.wide ? min(0.65 * size.width, 1.7 * size.height) : 0.65 * size.width
    }

    func uniforms(pixels: CGSize, t: Double, headroom: Float, tilt: CGPoint, frameIndex: Int, rainCount: Int,
                  budget: SkyBudget, meteor: SkyMeteor?) -> SkyUniforms {
        var u = SkyUniforms()
        u.res = [Float(pixels.width), Float(pixels.height), 1 / Float(pixels.width), 1 / Float(pixels.height)]
        u.view = [Float(size.width), Float(size.height), Float(t), Float(scene.rawValue)]
        let l = light
        u.light = [Float(l.center.x), Float(l.center.y), Float(l.radius), l.drawn ? 1 : 0]
        u.quality = [Float(budget.cloudSteps), Float(budget.lightSteps), budget.detail ? 1 : 0, Float(budget.farSteps)]
        let bloom: Float = scene == .clearDay ? 0.2 : (scene.isNight ? 0.3 : 0.15)
        u.tone = [headroom, Self.textLuminanceCap, Float(0.6) / 255, bloom]
        let small = Array(texts.small.prefix(4)), big = Array(texts.big.prefix(4 - small.count))
        let rects = small + big
        let feather = Float((SceneArt.Frame(size).wide ? 0.45 : 0.18) * min(size.width, size.height))
        u.parallax = [Float(tilt.x), Float(tilt.y), Float(rects.count), feather]
        let day = scene == .clearDay
        u.caps = [day ? Self.dayTextLuminanceCap : Self.textLuminanceCap, day ? Self.bigTextLuminanceCap : Self.textLuminanceCap,
                  day ? 40 : feather, day ? 48 : feather]
        for i in 0..<big.count { u.textBig[small.count + i] = 1 }
        let glow = SceneArt.Frame(size).wide ? 1.3 * size.height : max(size.width, min(size.height, 1.2 * size.width))
        u.sun = [Float(haloRadius), Float(glow),
                 Float(budget.cirrusOctaves), budget.haloPatches ? 1 : 0]
        let rayStrength: Float = scene == .nightCloudy ? 0.5 * Float(moonLit) : 0
        u.rays = [Float(budget.raySamples), l.drawn ? rayStrength : 0, Float(frameIndex % 64), Float(rainCount)]
        u.moon = [Float(moonAge), 0.35, 1, 0]
        if let m = meteor, scene.isNight {
            u.meteor0 = [Float(m.head.x), Float(m.head.y), Float(m.direction.dx), Float(m.direction.dy)]
            u.meteor1 = [Float(m.tail), Float(m.alpha), Float(m.width), 0]
        }
        u.meteor1.w = Float(budget.starLayers)
        for (i, r) in rects.enumerated() {
            u.text[i] = [Float(r.minX), Float(r.minY), Float(r.maxX), Float(r.maxY)]
        }
        return u
    }

    func rainCount() -> Int {
        guard scene == .rain else { return 0 }
        return min(quality.rainCap, Int(size.width * size.height * 0.014))
    }
}

/// 장치·파이프라인·구운 노이즈·달 지도 — 앱 전체에 하나.
final class SkyGPU {
    static let shared: SkyGPU? = try? SkyGPU()
    static let format: MTLPixelFormat = .rgba16Float
    static let transFormat: MTLPixelFormat = .r16Float
    static let noiseSize = 128

    let device: MTLDevice
    let queue: MTLCommandQueue
    let clouds, compose, rain, rays, final: MTLRenderPipelineState
    let rainUpdate, prefilter, down, up: MTLComputePipelineState
    let noise: MTLTexture
    /// NASA SVS CGI Moon Kit(LRO) 앞면 — 앱 타깃에만 있다. 없으면 셰이더가 무늬를 지어 그린다.
    let moon: MTLTexture
    let hasMoonMap: Bool

    private init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw CocoaError(.featureUnsupported)
        }
        self.device = device
        self.queue = queue
        let bundle = Bundle(for: SharedBundleMarker.self)
        let lib = try device.makeDefaultLibrary(bundle: bundle)
        func fn(_ n: String) throws -> MTLFunction {
            guard let f = lib.makeFunction(name: n) else { throw CocoaError(.featureUnsupported) }
            return f
        }
        func render(_ frag: String, vertex: String = "skyFullscreen", additive: Bool = false,
                    second: MTLPixelFormat? = nil) throws -> MTLRenderPipelineState {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = try fn(vertex)
            d.fragmentFunction = try fn(frag)
            d.colorAttachments[0].pixelFormat = Self.format
            if let second { d.colorAttachments[1].pixelFormat = second }
            if additive {
                let a = d.colorAttachments[0]!
                a.isBlendingEnabled = true
                a.rgbBlendOperation = .add
                a.alphaBlendOperation = .add
                a.sourceRGBBlendFactor = .one
                a.destinationRGBBlendFactor = .one
                a.sourceAlphaBlendFactor = .zero
                a.destinationAlphaBlendFactor = .one
            }
            return try device.makeRenderPipelineState(descriptor: d)
        }
        func compute(_ n: String) throws -> MTLComputePipelineState { try device.makeComputePipelineState(function: fn(n)) }
        clouds = try render("skyClouds", second: Self.transFormat)
        compose = try render("skyCompose")
        rain = try render("skyRainFragment", vertex: "skyRainVertex", additive: true)
        rays = try render("skyRays")
        final = try render("skyFinal")
        rainUpdate = try compute("skyRainUpdate")
        prefilter = try compute("skyBloomPrefilter")
        down = try compute("skyBloomDown")
        up = try compute("skyBloomUp")

        let nd = MTLTextureDescriptor()
        nd.textureType = .type3D
        nd.pixelFormat = .rgba8Unorm
        nd.width = Self.noiseSize; nd.height = Self.noiseSize; nd.depth = Self.noiseSize
        nd.usage = [.shaderRead, .shaderWrite]
        nd.storageMode = .private
        guard let noise = device.makeTexture(descriptor: nd), let cb = queue.makeCommandBuffer(),
              let enc = cb.makeComputeCommandEncoder() else { throw CocoaError(.featureUnsupported) }
        let bake = try compute("skyBakeNoise")
        enc.setComputePipelineState(bake)
        enc.setTexture(noise, index: 0)
        let tg = MTLSize(width: 4, height: 4, depth: 4)
        let n = (Self.noiseSize + 3) / 4
        enc.dispatchThreadgroups(MTLSize(width: n, height: n, depth: n), threadsPerThreadgroup: tg)
        enc.endEncoding()
        cb.commit()
        cb.waitUntilCompleted()
        self.noise = noise

        let loader = MTKTextureLoader(device: device)
        if let url = bundle.url(forResource: "MoonNear", withExtension: "jpg"),
           let tex = try? loader.newTexture(URL: url, options: [.SRGB: false, .generateMipmaps: true,
                                                                .textureStorageMode: MTLStorageMode.private.rawValue]) {
            moon = tex
            hasMoonMap = true
        } else {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 1, height: 1, mipmapped: false)
            guard let tex = device.makeTexture(descriptor: d) else { throw CocoaError(.featureUnsupported) }
            moon = tex
            hasMoonMap = false
        }
    }

    /// 디버그 — 구운 노이즈 네 채널의 분위수(5·25·50·75·95%). 구름 문턱을 맞출 때 본다.
    func noiseQuantiles() -> [[Float]] {
        let n = Self.noiseSize, bytes = n * n * n * 4
        guard let buf = device.makeBuffer(length: bytes, options: .storageModeShared),
              let cb = queue.makeCommandBuffer(), let blit = cb.makeBlitCommandEncoder() else { return [] }
        blit.copy(from: noise, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: n, height: n, depth: n), to: buf, destinationOffset: 0,
                  destinationBytesPerRow: n * 4, destinationBytesPerImage: n * n * 4)
        blit.endEncoding()
        cb.commit()
        cb.waitUntilCompleted()
        let p = buf.contents().bindMemory(to: UInt8.self, capacity: bytes)
        return (0..<4).map { ch in
            var hist = [Int](repeating: 0, count: 256)
            for i in stride(from: ch, to: bytes, by: 4 * 7) { hist[Int(p[i])] += 1 }
            let total = hist.reduce(0, +)
            return [0.05, 0.25, 0.5, 0.75, 0.95].map { q in
                var acc = 0
                for (v, c) in hist.enumerated() { acc += c; if Double(acc) >= q * Double(total) { return Float(v) / 255 } }
                return 1
            }
        }
    }
}

/// 구름 한 장 — 레이마칭한 시각(슬롯 번호)과 함께.
private final class CloudKey {
    let color: MTLTexture
    let trans: MTLTexture
    let upscaled: MTLTexture?
    var slot: Int?

    init(color: MTLTexture, trans: MTLTexture, upscaled: MTLTexture?) {
        self.color = color
        self.trans = trans
        self.upscaled = upscaled
    }

    var shown: MTLTexture { upscaled ?? color }
}

/// 한 장면을 그리는 패스 묶음. 대상 크기·무게가 바뀔 때만 중간 텍스처를 다시 만든다.
final class SkyRenderer {
    let gpu: SkyGPU
    private struct Key: Equatable { var w, h: Int; var scale: Double; var bloom: Int; var up: Double?; var scene: SkyScene }
    private var key: Key?
    private var keys: [CloudKey] = []
    #if canImport(MetalFX)
    private var scaler: MTLFXSpatialScaler?
    #else
    private var scaler: AnyObject?
    #endif
    private var hdrTex, raysTex: MTLTexture?
    private var downTex: [MTLTexture] = []
    private var upTex: [MTLTexture] = []
    private var drops: MTLBuffer?
    private(set) var frameIndex = 0
    /// 지금까지 구름을 레이마칭한 횟수(계측·테스트).
    private(set) var cloudRenders = 0
    private(set) var usingMetalFX = false

    init(gpu: SkyGPU) { self.gpu = gpu }

    private func texture(_ w: Int, _ h: Int, format: MTLPixelFormat = SkyGPU.format, usage: MTLTextureUsage) -> MTLTexture? {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: max(w, 1),
                                                         height: max(h, 1), mipmapped: false)
        d.usage = usage
        d.storageMode = .private
        return gpu.device.makeTexture(descriptor: d)
    }

    private func prepare(_ w: Int, _ h: Int, _ b: SkyBudget, _ scene: SkyScene) {
        let k = Key(w: w, h: h, scale: b.cloudScale, bloom: b.bloomLevels, up: b.upscaleTo, scene: scene)
        guard key != k else { return }
        let sizeChanged = key.map { $0.w != w || $0.h != h || $0.scale != b.cloudScale || $0.bloom != b.bloomLevels || $0.up != b.upscaleTo } ?? true
        key = k
        keys.forEach { $0.slot = nil }
        guard sizeChanged else { return }
        let rt: MTLTextureUsage = [.renderTarget, .shaderRead]
        let cw = max(Int(Double(w) * b.cloudScale), 1), ch = max(Int(Double(h) * b.cloudScale), 1)
        scaler = nil
        var outW = cw, outH = ch
        #if canImport(MetalFX)
        if let up = b.upscaleTo, MTLFXSpatialScalerDescriptor.supportsDevice(gpu.device) {
            outW = max(Int(Double(w) * up), cw); outH = max(Int(Double(h) * up), ch)
            let d = MTLFXSpatialScalerDescriptor()
            d.inputWidth = cw; d.inputHeight = ch
            d.outputWidth = outW; d.outputHeight = outH
            d.colorTextureFormat = SkyGPU.format
            d.outputTextureFormat = SkyGPU.format
            d.colorProcessingMode = .hdr
            scaler = d.makeSpatialScaler(device: gpu.device)
        }
        #endif
        usingMetalFX = scaler != nil
        keys = (0..<2).compactMap { _ in
            guard let c = texture(cw, ch, usage: rt), let t = texture(cw, ch, format: SkyGPU.transFormat, usage: rt) else { return nil }
            var upTex: MTLTexture?
            #if canImport(MetalFX)
            if let scaler {
                upTex = texture(outW, outH, usage: scaler.outputTextureUsage.union(.shaderRead))
            }
            #endif
            return CloudKey(color: c, trans: t, upscaled: upTex)
        }
        hdrTex = texture(w, h, usage: rt)
        raysTex = texture(w / 4, h / 4, usage: rt)
        downTex = []; upTex = []
        var bw = w / 2, bh = h / 2
        for _ in 0..<b.bloomLevels where bw >= 2 && bh >= 2 {
            if let d = texture(bw, bh, usage: [.shaderRead, .shaderWrite]),
               let u = texture(bw, bh, usage: [.shaderRead, .shaderWrite]) {
                downTex.append(d); upTex.append(u)
            }
            bw /= 2; bh /= 2
        }
    }

    private func pass(_ cb: MTLCommandBuffer, _ target: MTLTexture, load: MTLLoadAction = .dontCare) -> MTLRenderCommandEncoder? {
        let d = MTLRenderPassDescriptor()
        d.colorAttachments[0].texture = target
        d.colorAttachments[0].loadAction = load
        d.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        d.colorAttachments[0].storeAction = .store
        return cb.makeRenderCommandEncoder(descriptor: d)
    }

    private func dispatch(_ enc: MTLComputeCommandEncoder, _ w: Int, _ h: Int) {
        let tg = MTLSize(width: 8, height: 8, depth: 1)
        enc.dispatchThreadgroups(MTLSize(width: (w + 7) / 8, height: (h + 7) / 8, depth: 1), threadsPerThreadgroup: tg)
    }

    private func renderClouds(_ cb: MTLCommandBuffer, into k: CloudKey, uniforms: SkyUniforms, at time: Double) {
        var lowU = uniforms
        lowU.res = [Float(k.color.width), Float(k.color.height), 1 / Float(k.color.width), 1 / Float(k.color.height)]
        lowU.view.z = Float(time)
        let floats = lowU.floats
        let d = MTLRenderPassDescriptor()
        d.colorAttachments[0].texture = k.color
        d.colorAttachments[0].loadAction = .dontCare
        d.colorAttachments[0].storeAction = .store
        d.colorAttachments[1].texture = k.trans
        d.colorAttachments[1].loadAction = .dontCare
        d.colorAttachments[1].storeAction = .store
        guard let e = cb.makeRenderCommandEncoder(descriptor: d) else { return }
        e.setRenderPipelineState(gpu.clouds)
        floats.withUnsafeBytes { e.setFragmentBytes($0.baseAddress!, length: $0.count, index: 0) }
        e.setFragmentTexture(gpu.noise, index: 0)
        e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        e.endEncoding()
        #if canImport(MetalFX)
        if let scaler, let out = k.upscaled {
            scaler.colorTexture = k.color
            scaler.outputTexture = out
            scaler.inputContentWidth = k.color.width
            scaler.inputContentHeight = k.color.height
            scaler.encode(commandBuffer: cb)
        }
        #endif
        cloudRenders += 1
    }

    /// 구름 두 장(tA ≤ t < tB)과 섞는 값. 정지 그림(cloudEvery 0)은 t 그대로 한 장.
    private func cloudPair(_ cb: MTLCommandBuffer, _ u: SkyUniforms, t: Double, budget: SkyBudget)
        -> (CloudKey, CloudKey, SIMD3<Float>)? {
        guard keys.count == 2 else { return nil }
        guard budget.cloudEvery > 0 else {
            keys[0].slot = nil
            renderClouds(cb, into: keys[0], uniforms: u, at: t)
            return (keys[0], keys[0], .zero)
        }
        let dt = Double(budget.cloudEvery) / Double(max(budget.fps, 1))
        let a = Int((t / dt).rounded(.down)), b = a + 1
        func ensure(_ slot: Int, avoid: Int) -> CloudKey {
            if let k = keys.first(where: { $0.slot == slot }) { return k }
            let k = keys.first(where: { $0.slot != avoid }) ?? keys[0]
            renderClouds(cb, into: k, uniforms: u, at: Double(slot) * dt)
            k.slot = slot
            return k
        }
        let ka = ensure(a, avoid: b)
        let kb = ensure(b, avoid: a)
        let w = (t - Double(a) * dt) / dt
        return (ka, kb, SIMD3(Float(w), Float(t - Double(a) * dt), Float(Double(b) * dt - t)))
    }

    func encode(_ cb: MTLCommandBuffer, into target: MTLTexture, frame: SkyFrame, t: Double, headroom: Float,
                tilt: CGPoint = .zero, budget: SkyBudget? = nil, meteors: Bool = false) {
        let w = target.width, h = target.height
        guard w > 0, h > 0, frame.size.width > 0, frame.size.height > 0 else { return }
        let b = budget ?? SkyBudget(frame.quality, tier: .ultra, still: true)
        prepare(w, h, b, frame.scene)
        guard let hdrTex, let raysTex else { return }
        frameIndex += 1
        let rainN = frame.rainCount()
        let meteor = meteors && frame.scene.isNight
            ? SkyMeteor.at(t: t, size: frame.size, every: SkyDebug.frequentMeteors ? 5 : 25) : nil
        var u = frame.uniforms(pixels: CGSize(width: w, height: h), t: t, headroom: headroom, tilt: tilt,
                               frameIndex: frameIndex, rainCount: rainN, budget: b, meteor: meteor)
        u.moon.w = gpu.hasMoonMap ? 1 : 0
        guard let (ka, kb, mix) = cloudPair(cb, u, t: t, budget: b) else { return }
        u.blend = [mix.x, mix.y, mix.z, frame.scene.cloudFlow]
        let floats = u.floats
        let bytes = MemoryLayout<SIMD4<Float>>.stride * floats.count

        if rainN > 0 {
            let need = rainN * 2 * MemoryLayout<SIMD4<Float>>.stride
            if drops == nil || drops!.length < need { drops = gpu.device.makeBuffer(length: need, options: .storageModePrivate) }
            if let drops, let c = cb.makeComputeCommandEncoder() {
                c.setComputePipelineState(gpu.rainUpdate)
                c.setBuffer(drops, offset: 0, index: 0)
                floats.withUnsafeBytes { c.setBytes($0.baseAddress!, length: bytes, index: 1) }
                c.dispatchThreadgroups(MTLSize(width: (rainN + 63) / 64, height: 1, depth: 1),
                                       threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
                c.endEncoding()
            }
        }

        if let e = pass(cb, hdrTex) {
            e.setRenderPipelineState(gpu.compose)
            floats.withUnsafeBytes { e.setFragmentBytes($0.baseAddress!, length: bytes, index: 0) }
            e.setFragmentTexture(ka.shown, index: 0)
            e.setFragmentTexture(ka.trans, index: 1)
            e.setFragmentTexture(kb.shown, index: 2)
            e.setFragmentTexture(kb.trans, index: 3)
            e.setFragmentTexture(gpu.moon, index: 4)
            e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            if rainN > 0, let drops {
                e.setRenderPipelineState(gpu.rain)
                e.setVertexBuffer(drops, offset: 0, index: 0)
                floats.withUnsafeBytes { e.setVertexBytes($0.baseAddress!, length: bytes, index: 1) }
                e.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: rainN)
            }
            e.endEncoding()
        }

        if let e = pass(cb, raysTex, load: .clear) {
            if u.rays.x > 0, u.rays.y > 0 {
                var ru = u
                ru.res = [Float(raysTex.width), Float(raysTex.height), 0, 0]
                e.setRenderPipelineState(gpu.rays)
                ru.floats.withUnsafeBytes { e.setFragmentBytes($0.baseAddress!, length: bytes, index: 0) }
                e.setFragmentTexture(mix.x < 0.5 ? ka.trans : kb.trans, index: 0)
                e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }
            e.endEncoding()
        }

        if !downTex.isEmpty, let c = cb.makeComputeCommandEncoder() {
            var p = SIMD4<Float>(1.1, 0.5, 0, 0)
            c.setComputePipelineState(gpu.prefilter)
            c.setTexture(hdrTex, index: 0)
            c.setTexture(downTex[0], index: 1)
            c.setBytes(&p, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            dispatch(c, downTex[0].width, downTex[0].height)
            c.setComputePipelineState(gpu.down)
            for i in 1..<downTex.count {
                c.setTexture(downTex[i - 1], index: 0)
                c.setTexture(downTex[i], index: 1)
                dispatch(c, downTex[i].width, downTex[i].height)
            }
            c.setComputePipelineState(gpu.up)
            let last = downTex.count - 1
            for i in stride(from: last - 1, through: 0, by: -1) {
                c.setTexture(i + 1 == last ? downTex[last] : upTex[i + 1], index: 0)
                c.setTexture(downTex[i], index: 1)
                c.setTexture(upTex[i], index: 2)
                dispatch(c, upTex[i].width, upTex[i].height)
            }
            c.endEncoding()
        }
        let bloomTex = downTex.count > 1 ? upTex[0] : (downTex.first ?? raysTex)

        if let e = pass(cb, target) {
            e.setRenderPipelineState(gpu.final)
            floats.withUnsafeBytes { e.setFragmentBytes($0.baseAddress!, length: bytes, index: 0) }
            e.setFragmentTexture(hdrTex, index: 0)
            e.setFragmentTexture(bloomTex, index: 1)
            e.setFragmentTexture(raysTex, index: 2)
            e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            e.endEncoding()
        }
    }
}

// MARK: - 정지 그림 (위젯·비교 PNG)

public enum SkySnapshot {
    /// SDR 로 굳힌 한 장 — 위젯은 앱이 이걸 App Group 에 PNG 로 구워 두고 띄우면 된다.
    /// gpuMilliseconds: 같은 프레임을 repeats 번 그려 잰 GPU 시간 평균(시뮬레이터는 참고만).
    public static func image(_ frame: SkyFrame, scale: CGFloat, t: Double, headroom: Float = 1,
                             repeats: Int = 1, tier: SkyTier = .ultra, meteors: Bool = false)
        -> (image: CGImage, gpuMilliseconds: Double)? {
        guard let gpu = SkyGPU.shared else { return nil }
        let w = Int(frame.size.width * scale), h = Int(frame.size.height * scale)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: SkyGPU.format, width: w, height: h, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .private
        guard let target = gpu.device.makeTexture(descriptor: d) else { return nil }
        let renderer = SkyRenderer(gpu: gpu)
        let budget = SkyBudget(frame.quality, tier: tier, still: true)
        var total = 0.0
        for i in 0..<max(repeats, 1) {
            guard let cb = gpu.queue.makeCommandBuffer() else { return nil }
            renderer.encode(cb, into: target, frame: frame, t: t, headroom: headroom, budget: budget, meteors: meteors)
            let start = CACurrentMediaTime()
            cb.commit()
            cb.waitUntilCompleted()
            let gpu = (cb.gpuEndTime - cb.gpuStartTime) * 1000
            if i > 0 || repeats == 1 { total += max(gpu, (CACurrentMediaTime() - start) * 1000) }
        }
        let ms = total / Double(max(repeats - 1, 1))
        guard let linear = CGColorSpace(name: CGColorSpace.extendedLinearSRGB),
              let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let ci = CIImage(mtlTexture: target, options: [.colorSpace: linear]) else { return nil }
        let ctx = CIContext(mtlDevice: gpu.device, options: [.workingColorSpace: linear])
        let flipped = ci.oriented(.downMirrored)
        guard let cg = ctx.createCGImage(flipped, from: flipped.extent, format: .RGBA8, colorSpace: srgb) else { return nil }
        return (cg, ms)
    }

    /// 움직이는 하늘처럼 프레임을 이어 그려 구름 레이마칭 횟수를 센다(GPU 결과는 버린다).
    public static func cloudRenders(_ frame: SkyFrame, tier: SkyTier, seconds: Double, scale: CGFloat = 1) -> (renders: Int, frames: Int) {
        guard let gpu = SkyGPU.shared else { return (0, 0) }
        let budget = SkyBudget(frame.quality, tier: tier)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: SkyGPU.format, width: Int(frame.size.width * scale),
                                                         height: Int(frame.size.height * scale), mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .private
        guard let target = gpu.device.makeTexture(descriptor: d) else { return (0, 0) }
        let renderer = SkyRenderer(gpu: gpu)
        let n = Int(seconds * Double(budget.fps))
        for i in 0..<n {
            guard let cb = gpu.queue.makeCommandBuffer() else { break }
            renderer.encode(cb, into: target, frame: frame, t: 100 + Double(i) / Double(budget.fps), headroom: 1, budget: budget)
            cb.commit()
            if i == n - 1 { cb.waitUntilCompleted() }
        }
        return (renderer.cloudRenders, n)
    }
}

// MARK: - 기울기 시차

@MainActor
final class SkyTilt {
    static let shared = SkyTilt()
    private let manager = CMMotionManager()
    private var users = 0
    private(set) var offset: CGPoint = .zero

    func retain() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let g = m?.gravity else { return }
            let target = CGPoint(x: g.x * 14, y: (g.y + 0.6) * 10)
            self.offset = CGPoint(x: self.offset.x + (target.x - self.offset.x) * 0.15,
                                  y: self.offset.y + (target.y - self.offset.y) * 0.15)
        }
    }

    func release() {
        users = max(0, users - 1)
        if users == 0 { manager.stopDeviceMotionUpdates(); offset = .zero }
    }
}

// MARK: - 뷰

/// Decorative — VoiceOver 에선 숨긴다. animating 은 호출부 스위치(보이는 카드만), 동작 줄이기면 언제나 멈춘 한 장(별똥별 없음).
public struct SkyView: UIViewRepresentable {
    private let scene: SkyScene
    private let quality: SkyQuality
    private let animating: Bool
    private let phase: Double
    private let texts: SkyTexts?
    private let tilts: Bool
    private let moonAge: Double?

    /// moonAge nil 이면 오늘 달 나이(Celestial).
    public init(_ scene: SkyScene, quality: SkyQuality = .card, animating: Bool = false,
                phase: Double = SceneArt.stillPhase, texts: SkyTexts? = nil, tilts: Bool = false,
                moonAge: Double? = nil) {
        self.scene = scene
        self.quality = quality
        self.animating = animating
        self.phase = phase
        self.texts = texts
        self.tilts = tilts
        self.moonAge = moonAge
    }

    public func makeCoordinator() -> Coordinator { Coordinator(phase: phase) }

    public func makeUIView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: SkyGPU.shared?.device)
        v.colorPixelFormat = SkyGPU.format
        v.framebufferOnly = true
        v.isOpaque = true
        v.backgroundColor = .black
        v.autoResizeDrawable = true
        if let layer = v.layer as? CAMetalLayer {
            layer.wantsExtendedDynamicRangeContent = true
            layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        }
        v.delegate = context.coordinator
        v.isAccessibilityElement = false
        context.coordinator.renderer = SkyGPU.shared.map(SkyRenderer.init(gpu:))
        return v
    }

    public func updateUIView(_ v: MTKView, context: Context) {
        let c = context.coordinator
        let running = animating && !context.environment.accessibilityReduceMotion
        c.scene = scene
        c.quality = quality
        c.texts = texts
        c.moonAge = moonAge
        c.running = running
        c.setTilt(tilts && running)
        c.clock.set(running: running, at: Date())
        v.preferredFramesPerSecond = c.budget(for: v).fps
        v.enableSetNeedsDisplay = !running
        v.isPaused = !running
        if !running { v.setNeedsDisplay() }
    }

    public static func dismantleUIView(_ v: MTKView, coordinator: Coordinator) {
        v.isPaused = true
        coordinator.setTilt(false)
    }

    @MainActor
    public final class Coordinator: NSObject, MTKViewDelegate {
        var renderer: SkyRenderer?
        var scene: SkyScene = .nightCloudy
        var quality: SkyQuality = .card
        var texts: SkyTexts?
        var moonAge: Double?
        var running = false
        var clock: SceneTime
        private var tilting = false
        private var lastRenders = 0

        init(phase: Double) { clock = SceneTime(phase: phase) }

        func setTilt(_ on: Bool) {
            guard on != tilting else { return }
            tilting = on
            on ? SkyTilt.shared.retain() : SkyTilt.shared.release()
        }

        func budget(for view: MTKView) -> SkyBudget {
            let maxFPS = view.window?.windowScene?.screen.maximumFramesPerSecond ?? UIScreen.main.maximumFramesPerSecond
            let tier = SkyDebug.tier ?? renderer.map { SkyTier.detect($0.gpu.device, maxFPS: maxFPS) } ?? .mid
            let info = ProcessInfo.processInfo
            return SkyBudget(quality, tier: tier, thermal: info.thermalState, lowPower: info.isLowPowerModeEnabled,
                             metalFX: SkyDebug.metalFX, still: !running)
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { view.setNeedsDisplay() }

        public func draw(in view: MTKView) {
            guard let renderer, let drawable = view.currentDrawable,
                  let cb = renderer.gpu.queue.makeCommandBuffer() else { return }
            let b = budget(for: view)
            if view.preferredFramesPerSecond != b.fps { view.preferredFramesPerSecond = b.fps }
            let size = view.bounds.size
            let headroom = Float(min(max(view.window?.windowScene?.screen.currentEDRHeadroom ?? 1, 1), 4))
            let frame = SkyFrame(scene: scene, quality: quality, size: size, texts: texts,
                                 moonAge: SkyDebug.moonAge ?? moonAge ?? Celestial.moonAge(at: Date()),
                                 moonScale: SkyDebug.moonScale)
            renderer.encode(cb, into: drawable.texture, frame: frame, t: clock.time(at: Date()), headroom: headroom,
                            tilt: tilting ? SkyTilt.shared.offset : .zero, budget: b, meteors: running)
            do {
                let q = quality
                let rendered = renderer.cloudRenders - lastRenders
                lastRenders = renderer.cloudRenders
                let label = "\(b.tier.name)\(b.hot ? "(발열)" : "")\(renderer.usingMetalFX ? " · MetalFX" : "")"
                SkyStats.shared.tick(q, now: CACurrentMediaTime(), cloudRendered: rendered, label: label)
                cb.addCompletedHandler { cb in
                    SkyStats.shared.frame(q, gpuMs: (cb.gpuEndTime - cb.gpuStartTime) * 1000)
                }
            }
            cb.present(drawable)
            cb.commit()
        }
    }
}
