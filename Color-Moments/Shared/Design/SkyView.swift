import CoreMotion
import MetalKit
import SwiftUI

/// 스파이크 — Apple 날씨 같은 하늘. 장면 셋만(밤 흐림·맑은 낮·비). 판정 뒤에 SceneView 를 갈아끼운다.
public enum SkyScene: Int, CaseIterable, Identifiable, Sendable {
    case nightCloudy, clearDay, rain

    public var id: Int { rawValue }

    public var name: String {
        switch self {
        case .nightCloudy: "밤 흐림"
        case .clearDay: "맑은 낮"
        case .rain: "비"
        }
    }

    /// 지금 장면에서 가장 가까운 것 — 나란히 비교할 때.
    public var legacy: SceneKind {
        switch self {
        case .nightCloudy: .moon
        case .clearDay: .sun
        case .rain: .rain
        }
    }
}

/// 품질 단계 — 무게는 전부 여기서 조절한다.
public enum SkyQuality: String, CaseIterable, Identifiable, Sendable {
    /// 전체 화면 하늘(60fps)
    case full
    /// 오늘의 한 장(60fps)
    case hero
    /// 목록 카드(30fps, 화면 밖은 멈춤)
    case card

    public var id: String { rawValue }

    /// 구름을 그리는 해상도(화면 픽셀 대비)
    var cloudScale: Double { switch self { case .full: 0.5; case .hero: 0.5; case .card: 0.34 } }
    /// 가까운 구름층 레이마칭 걸음
    var cloudSteps: Int { switch self { case .full: 26; case .hero: 24; case .card: 12 } }
    /// 먼 구름층 걸음
    var farSteps: Int { switch self { case .full: 12; case .hero: 12; case .card: 6 } }
    /// 해·달 쪽으로 그림자 재는 걸음
    var lightSteps: Int { switch self { case .full: 6; case .hero: 5; case .card: 3 } }
    /// 가장자리 잔결(노이즈 한 번 더)
    var detail: Bool { self != .card }
    var rainCap: Int { switch self { case .full: 6000; case .hero: 2400; case .card: 700 } }
    var bloomLevels: Int { switch self { case .full: 6; case .hero: 5; case .card: 4 } }
    var raySamples: Int { switch self { case .full: 48; case .hero: 32; case .card: 0 } }
    public var fps: Int { self == .card ? 30 : 60 }
}

/// 셰이더 SkyU 와 같은 배치 — float4 × 11.
struct SkyUniforms {
    var res = SIMD4<Float>(repeating: 0)
    var view = SIMD4<Float>(repeating: 0)
    var light = SIMD4<Float>(repeating: 0)
    var quality = SIMD4<Float>(repeating: 0)
    var tone = SIMD4<Float>(repeating: 0)
    var parallax = SIMD4<Float>(repeating: 0)
    var rays = SIMD4<Float>(repeating: 0)
    var text: [SIMD4<Float>] = Array(repeating: .zero, count: 4)

    var floats: [SIMD4<Float>] { [res, view, light, quality, tone, parallax, rays] + text }
}

/// 장면·크기에서 정해지는 것(픽셀마다 같은 값).
public struct SkyFrame: Equatable {
    public var scene: SkyScene
    public var quality: SkyQuality
    public var size: CGSize
    public var textRects: [CGRect]

    public init(scene: SkyScene, quality: SkyQuality, size: CGSize, textRects: [CGRect]? = nil) {
        self.scene = scene
        self.quality = quality
        self.size = size
        self.textRects = textRects ?? SceneArt.textRects(in: size)
    }

    /// 해·달 자리(pt)와 반지름. 비는 위쪽 먼 곳의 흐린 빛(그리지 않음).
    var light: (center: CGPoint, radius: CGFloat, drawn: Bool) {
        let w = size.width, h = size.height, u = min(w, h)
        if scene == .rain { return (CGPoint(x: 0.5 * w, y: -2.2 * 320), 0, false) }
        if h > 1.3 * w {
            return scene == .nightCloudy ? (CGPoint(x: 0.84 * w, y: 0.085 * h), 15, true)
                                         : (CGPoint(x: 0.84 * w, y: 0.06 * h), 9, true)
        }
        let f = SceneArt.Frame(size)
        if f.wide { return (CGPoint(x: f.pane.midX, y: 0.42 * h), scene == .nightCloudy ? 0.11 * u : 0.07 * u, true) }
        return scene == .nightCloudy ? (CGPoint(x: w - 0.2 * u, y: 0.2 * u), 0.075 * u, true)
                                     : (CGPoint(x: w - 0.17 * u, y: 0.16 * u), 0.036 * u, true)
    }

    /// 글자 자리 위 하늘의 최대 상대 휘도 — 흰 64%(secondary) 글자가 4.5:1 을 넘게.
    static let textLuminanceCap: Float = 0.07

    func uniforms(pixels: CGSize, t: Double, headroom: Float, tilt: CGPoint, frameIndex: Int, rainCount: Int) -> SkyUniforms {
        var u = SkyUniforms()
        u.res = [Float(pixels.width), Float(pixels.height), 1 / Float(pixels.width), 1 / Float(pixels.height)]
        u.view = [Float(size.width), Float(size.height), Float(t), Float(scene.rawValue)]
        let l = light
        u.light = [Float(l.center.x), Float(l.center.y), Float(l.radius), l.drawn ? 1 : 0]
        u.quality = [Float(quality.cloudSteps), Float(quality.lightSteps), quality.detail ? 1 : 0, Float(quality.farSteps)]
        let bloom: Float = scene == .clearDay ? 0.2 : (scene == .nightCloudy ? 0.3 : 0.15)
        u.tone = [headroom, Self.textLuminanceCap, Float(0.6) / 255, bloom]
        let rects = Array(textRects.prefix(4))
        u.parallax = [Float(tilt.x), Float(tilt.y), Float(rects.count), Float((SceneArt.Frame(size).wide ? 0.45 : 0.18) * min(size.width, size.height))]
        let rayStrength: Float = scene == .nightCloudy ? 0.5 : 0
        u.rays = [Float(quality.raySamples), l.drawn ? rayStrength : 0, Float(frameIndex % 64), Float(rainCount)]
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

/// 장치·파이프라인·구운 노이즈 — 앱 전체에 하나.
final class SkyGPU {
    static let shared: SkyGPU? = try? SkyGPU()
    static let format: MTLPixelFormat = .rgba16Float
    static let noiseSize = 128

    let device: MTLDevice
    let queue: MTLCommandQueue
    let clouds, compose, rain, rays, final: MTLRenderPipelineState
    let rainUpdate, prefilter, down, up: MTLComputePipelineState
    let noise: MTLTexture

    private init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw CocoaError(.featureUnsupported)
        }
        self.device = device
        self.queue = queue
        let lib = try device.makeDefaultLibrary(bundle: Bundle(for: SharedBundleMarker.self))
        func fn(_ n: String) throws -> MTLFunction {
            guard let f = lib.makeFunction(name: n) else { throw CocoaError(.featureUnsupported) }
            return f
        }
        func render(_ frag: String, vertex: String = "skyFullscreen", additive: Bool = false) throws -> MTLRenderPipelineState {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = try fn(vertex)
            d.fragmentFunction = try fn(frag)
            d.colorAttachments[0].pixelFormat = Self.format
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
        clouds = try render("skyClouds")
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

/// 한 장면을 그리는 패스 묶음. 대상 크기가 바뀔 때만 중간 텍스처를 다시 만든다.
final class SkyRenderer {
    let gpu: SkyGPU
    private var key: (Int, Int, Double, Int) = (0, 0, 0, 0)
    private var cloudTex, hdrTex, raysTex: MTLTexture?
    private var downTex: [MTLTexture] = []
    private var upTex: [MTLTexture] = []
    private var drops: MTLBuffer?
    private(set) var frameIndex = 0

    init(gpu: SkyGPU) { self.gpu = gpu }

    private func texture(_ w: Int, _ h: Int, usage: MTLTextureUsage) -> MTLTexture? {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: SkyGPU.format, width: max(w, 1),
                                                         height: max(h, 1), mipmapped: false)
        d.usage = usage
        d.storageMode = .private
        return gpu.device.makeTexture(descriptor: d)
    }

    private func prepare(_ w: Int, _ h: Int, _ q: SkyQuality) {
        guard key != (w, h, q.cloudScale, q.bloomLevels) else { return }
        key = (w, h, q.cloudScale, q.bloomLevels)
        let rt: MTLTextureUsage = [.renderTarget, .shaderRead]
        cloudTex = texture(Int(Double(w) * q.cloudScale), Int(Double(h) * q.cloudScale), usage: rt)
        hdrTex = texture(w, h, usage: rt)
        raysTex = texture(w / 4, h / 4, usage: rt)
        downTex = []; upTex = []
        var bw = w / 2, bh = h / 2
        for _ in 0..<q.bloomLevels where bw >= 2 && bh >= 2 {
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

    func encode(_ cb: MTLCommandBuffer, into target: MTLTexture, frame: SkyFrame, t: Double, headroom: Float,
                tilt: CGPoint = .zero) {
        let w = target.width, h = target.height
        guard w > 0, h > 0, frame.size.width > 0, frame.size.height > 0 else { return }
        prepare(w, h, frame.quality)
        guard let cloudTex, let hdrTex, let raysTex else { return }
        frameIndex += 1
        let rainN = frame.rainCount()
        var u = frame.uniforms(pixels: CGSize(width: w, height: h), t: t, headroom: headroom, tilt: tilt,
                               frameIndex: frameIndex, rainCount: rainN)
        var lowU = u
        lowU.res = [Float(cloudTex.width), Float(cloudTex.height), 1 / Float(cloudTex.width), 1 / Float(cloudTex.height)]
        let floats = u.floats, lowFloats = lowU.floats
        let bytes = MemoryLayout<SIMD4<Float>>.stride * floats.count

        if let e = pass(cb, cloudTex) {
            e.setRenderPipelineState(gpu.clouds)
            lowFloats.withUnsafeBytes { e.setFragmentBytes($0.baseAddress!, length: bytes, index: 0) }
            e.setFragmentTexture(gpu.noise, index: 0)
            e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            e.endEncoding()
        }

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
            e.setFragmentTexture(cloudTex, index: 0)
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
                e.setFragmentTexture(cloudTex, index: 0)
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
        u.res = .zero
    }
}

// MARK: - 정지 그림 (위젯·비교 PNG)

public enum SkySnapshot {
    /// SDR 로 굳힌 한 장 — 위젯은 앱이 이걸 App Group 에 PNG 로 구워 두고 띄우면 된다.
    /// gpuMilliseconds: 같은 프레임을 repeats 번 그려 잰 GPU 시간 평균(시뮬레이터는 참고만).
    public static func image(_ frame: SkyFrame, scale: CGFloat, t: Double, headroom: Float = 1,
                             repeats: Int = 1) -> (image: CGImage, gpuMilliseconds: Double)? {
        guard let gpu = SkyGPU.shared else { return nil }
        let w = Int(frame.size.width * scale), h = Int(frame.size.height * scale)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: SkyGPU.format, width: w, height: h, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .private
        guard let target = gpu.device.makeTexture(descriptor: d) else { return nil }
        let renderer = SkyRenderer(gpu: gpu)
        var total = 0.0
        for i in 0..<max(repeats, 1) {
            guard let cb = gpu.queue.makeCommandBuffer() else { return nil }
            renderer.encode(cb, into: target, frame: frame, t: t, headroom: headroom)
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

/// Decorative — VoiceOver 에선 숨긴다. animating 은 호출부 스위치(보이는 카드만), 동작 줄이기면 언제나 멈춘 한 장.
public struct SkyView: UIViewRepresentable {
    private let scene: SkyScene
    private let quality: SkyQuality
    private let animating: Bool
    private let phase: Double
    private let textRects: [CGRect]?
    private let tilts: Bool

    public init(_ scene: SkyScene, quality: SkyQuality = .card, animating: Bool = false,
                phase: Double = SceneArt.stillPhase, textRects: [CGRect]? = nil, tilts: Bool = false) {
        self.scene = scene
        self.quality = quality
        self.animating = animating
        self.phase = phase
        self.textRects = textRects
        self.tilts = tilts
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
        c.textRects = textRects
        c.setTilt(tilts && running)
        c.clock.set(running: running, at: Date())
        v.preferredFramesPerSecond = quality.fps
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
        var textRects: [CGRect]?
        var clock: SceneTime
        private var tilting = false

        init(phase: Double) { clock = SceneTime(phase: phase) }

        func setTilt(_ on: Bool) {
            guard on != tilting else { return }
            tilting = on
            on ? SkyTilt.shared.retain() : SkyTilt.shared.release()
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { view.setNeedsDisplay() }

        public func draw(in view: MTKView) {
            guard let renderer, let drawable = view.currentDrawable,
                  let cb = renderer.gpu.queue.makeCommandBuffer() else { return }
            let size = view.bounds.size
            let headroom = Float(min(max(view.window?.windowScene?.screen.currentEDRHeadroom ?? 1, 1), 4))
            let frame = SkyFrame(scene: scene, quality: quality, size: size, textRects: textRects)
            renderer.encode(cb, into: drawable.texture, frame: frame, t: clock.time(at: Date()), headroom: headroom,
                            tilt: tilting ? SkyTilt.shared.offset : .zero)
            cb.present(drawable)
            cb.commit()
        }
    }
}
