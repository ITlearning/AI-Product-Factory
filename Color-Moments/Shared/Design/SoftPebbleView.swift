import SwiftUI

struct SoftPebbleShape: Equatable {
    let tilt: Double
    let egg: Double
    let wa, wb, wc: Double

    init(tilt: Double, egg: Double, wa: Double, wb: Double, wc: Double) {
        self.tilt = tilt
        self.egg = egg
        self.wa = wa
        self.wb = wb
        self.wc = wc
    }

    init(dayKey: String) {
        let h = PebbleSilhouette(dayKey: dayKey).seed
        func pick(_ shift: UInt64) -> Double { Double((h >> shift) & 0xFF) / 255 }
        // 넓은 쪽이 아래로 오게 — 오른쪽 아래 또는 왼쪽 아래
        let mirrored = (h >> 32) & 1 == 1
        let deg = mirrored ? 125 + pick(40) * 70 : -15 + pick(40) * 70
        self.init(tilt: deg * .pi / 180, egg: 0.12 + pick(48) * 0.16,
                  wa: pick(8), wb: pick(16), wc: pick(24))
    }

    func rho(_ x: Double, _ y: Double) -> Double {
        let u = x * cos(tilt) + y * sin(tilt)
        let v = -x * sin(tilt) + y * cos(tilt)
        let vs = v / (1 + egg * u)
        let th = atan2(vs, u)
        let wob = 1 + 0.012 * cos(3 * th + wa * 6.3) + 0.006 * cos(5 * th + wb * 6.3)
            + 0.012 * cos(2 * th + wc * 6.3)
        return sqrt((u / 1.04) * (u / 1.04) + vs * vs) / wob
    }

    /// 윤곽의 가장 낮은 점(y)과 면적 중심(x) — 바닥 번짐·접지 그림자가 여기 붙는다. 반지름 1 좌표계.
    var floorAnchor: CGPoint {
        let pts = outline(points: 180).map { (Double($0.x), Double($0.y)) }
        let n = pts.count
        var area = 0.0, cx = 0.0, bottom = -Double.infinity
        for i in 0..<n {
            let (x0, y0) = pts[i], (x1, y1) = pts[(i + 1) % n]
            let cross = x0 * y1 - x1 * y0
            area += cross
            cx += (x0 + x1) * cross
            bottom = max(bottom, y0)
        }
        return CGPoint(x: area == 0 ? 0 : cx / (3 * area), y: bottom)
    }
}

extension SoftPebbleShape: Hashable {}

extension SoftPebbleShape {
    /// 색 없는 자리(점선 조약돌)에 쓰는 기본 모양 — 아이콘과 같은 기울기.
    static let placeholder = SoftPebbleShape(tilt: 32 * .pi / 180, egg: 0.22, wa: 0.3, wb: 0.6, wc: 0.4)

    /// 반지름 1 좌표계의 윤곽 점들(반시계 아님 — 각도 순서).
    func outline(points n: Int = 120) -> [CGPoint] {
        (0..<n).map { i in
            let phi = Double(i) / Double(n) * 2 * .pi
            let dx = cos(phi), dy = sin(phi)
            var lo = 0.0, hi = 2.0
            for _ in 0..<22 {
                let mid = (lo + hi) / 2
                if rho(dx * mid, dy * mid) < 1 { lo = mid } else { hi = mid }
            }
            return CGPoint(x: dx * lo, y: dy * lo)
        }
    }
}

/// 새 조약돌 윤곽을 rect 가운데에 지름 = rect 높이로 그린다.
struct SoftPebbleOutline: Shape {
    var shape: SoftPebbleShape = .placeholder

    func path(in rect: CGRect) -> Path {
        let r = rect.height / 2
        let pts = shape.outline().map { CGPoint(x: rect.midX + $0.x * r, y: rect.midY + $0.y * r) }
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        pts.dropFirst().forEach { p.addLine(to: $0) }
        p.closeSubpath()
        return p
    }
}

/// 조약돌 하나에서 픽셀마다 같은 값 — 셰이더가 매 픽셀 다시 계산하지 않게 CPU 가 한 번만 만든다.
struct SoftPebbleUniforms {
    static let lutSize = 128

    let frame: SIMD4<Float>
    let wob23: SIMD4<Float>
    let wob5: SIMD4<Float>
    let table: [Float]

    init(shape: SoftPebbleShape, stops: [Float], radius: CGFloat) {
        let anchor = shape.floorAnchor
        let p2 = shape.wc * 6.3, p3 = shape.wa * 6.3, p5 = shape.wb * 6.3
        frame = [Float(cos(shape.tilt)), Float(sin(shape.tilt)), Float(shape.egg), Float(radius)]
        wob23 = [Float(cos(p2)), Float(sin(p2)), Float(cos(p3)), Float(sin(p3))]
        wob5 = [Float(cos(p5)), Float(sin(p5)), Float(anchor.x), Float(anchor.y)]
        table = Self.table(stops)
    }

    /// 3줄 × lutSize × RGB — 0 띠 색, 1 후광 색(넓게 흐리고 10% 밝게), 2 테두리 빛 색(35% 밝게)
    static func table(_ stops: [Float]) -> [Float] {
        let n = lutSize
        var out = [Float](repeating: 0, count: 3 * n * 3)
        func put(_ row: Int, _ i: Int, _ c: SIMD3<Float>) {
            let k = (row * n + i) * 3
            out[k] = c.x; out[k + 1] = c.y; out[k + 2] = c.z
        }
        func lighten(_ c: SIMD3<Float>, _ k: Float) -> SIMD3<Float> { c + (SIMD3(repeating: 1) - c) * k }
        for i in 0..<n {
            let t = Float(i) / Float(n - 1)
            var acc = SIMD3<Float>(repeating: 0), wsum: Float = 0
            for j in -3...3 {
                let o = Float(j) * 0.1
                let w = exp(-(o * o) / (2 * 0.2 * 0.2))
                acc += ramp(stops, t + o) * w
                wsum += w
            }
            put(0, i, ramp(stops, t))
            put(1, i, lighten(acc / wsum, 0.10))
            put(2, i, lighten(ramp(stops, t), 0.35))
        }
        return out
    }

    /// stops: [위치, r, g, b] × n. 정지점 사이는 smoothstep 으로 섞는다(레퍼런스와 같게).
    static func ramp(_ stops: [Float], _ t: Float) -> SIMD3<Float> {
        let count = stops.count / 4
        let t = min(1, max(0, t))
        func color(_ i: Int) -> SIMD3<Float> { [stops[i * 4 + 1], stops[i * 4 + 2], stops[i * 4 + 3]] }
        guard count > 1, t > stops[0] else { return color(0) }
        for i in 0..<(count - 1) where t <= stops[(i + 1) * 4] {
            var u = (t - stops[i * 4]) / max(1e-5, stops[(i + 1) * 4] - stops[i * 4])
            u = u * u * (3 - 2 * u)
            return color(i) + (color(i + 1) - color(i)) * u
        }
        return color(count - 1)
    }
}

private struct UniformsKey: Hashable {
    let shape: SoftPebbleShape
    let stops: [Float]
    let radius: CGFloat
}

@MainActor
private enum SoftPebbleCache {
    static var uniforms: [UniformsKey: SoftPebbleUniforms] = [:]

    static func uniforms(_ key: UniformsKey) -> SoftPebbleUniforms {
        if let u = uniforms[key] { return u }
        if uniforms.count > 400 { uniforms.removeAll(keepingCapacity: true) }
        let u = SoftPebbleUniforms(shape: key.shape, stops: key.stops, radius: key.radius)
        uniforms[key] = u
        return u
    }
}

public struct SoftPebbleView: View {
    /// grid 격자·여러 개(은은하게), hero 하나를 크게, photo 사진 위(바닥이 없어 번짐·접지 그림자 없이 그림자만),
    /// bare 뒤에 이미 빛이 깔린 장면(온보딩 첫 화면) — 후광·바닥 번짐 없이 접지 그림자만
    public enum Glow {
        case grid, hero, photo, bare

        var halo: Float {
            switch self { case .grid: 0.18; case .hero: 0.4; case .photo: 0.15; case .bare: 0 }
        }
        var floor: Float {
            switch self { case .grid: 0.35; case .hero: 0.5; case .photo, .bare: 0 }
        }
        var contact: Float { self == .photo ? 0 : 1 }
        /// 돌 지름 대비 캔버스(후광이 번질 자리) 배율
        var canvas: CGFloat { self == .hero ? 1 / 0.54 : 1 / 0.66 }
    }

    /// 디버그 — 켜면 위젯도 셰이더 조약돌을 쓴다(실기기에서 위젯이 셰이더를 그리는지 확인용). App Group 기본값.
    public static let widgetDebugKey = "debugWidgetSoftPebble"

    private let height: CGFloat
    private let glow: Glow
    private let shape: SoftPebbleShape
    private let stops: [Float]
    private let sheen: Double
    @Environment(\.displayScale) private var displayScale

    public init(moments: [Moment], height: CGFloat, glow: Glow = .grid, sheen: Double = 0) {
        let key = moments.first.map(\.dayKey) ?? Moment.dayKey(for: Date())
        self.init(stops: Self.floats(DayGradient.stops(for: moments)), height: height, glow: glow,
                  shape: SoftPebbleShape(dayKey: key), sheen: sheen)
    }

    init(stops: [Float], height: CGFloat, glow: Glow, shape: SoftPebbleShape, sheen: Double = 0) {
        self.height = height
        self.glow = glow
        self.shape = shape
        self.stops = stops.isEmpty ? [0, 0.35, 0.35, 0.36] : stops
        self.sheen = sheen
    }

    public var body: some View {
        let side = height * glow.canvas
        let u = SoftPebbleCache.uniforms(UniformsKey(shape: shape, stops: stops, radius: height / 2))
        Rectangle()
            .frame(width: side, height: side)
            .colorEffect(ShaderLibrary.softPebble(
                .float2(side, side),
                .float4(u.frame.x, u.frame.y, u.frame.z, u.frame.w),
                .float4(u.wob23.x, u.wob23.y, u.wob23.z, u.wob23.w),
                .float4(u.wob5.x, u.wob5.y, u.wob5.z, u.wob5.w),
                .float4(glow.halo, glow.floor, Float(displayScale), glow.contact),
                .float4(Float(-1.3 + 2.6 * sheen), sheenAmount, 0, 0),
                .floatArray(u.table)))
            .shadow(color: .black.opacity(glow == .photo ? 0.35 : 0), radius: 6, y: 3)
            .frame(width: height, height: height)
            .allowsHitTesting(false)
    }

    /// 첫 조약돌이 그려지는 순간 셰이더 컴파일로 프레임이 끊기지 않게 미리 굽는다. 인자 모양만 같으면 된다.
    public static func precompile() async {
        try? await compileShader()
    }

    /// 인자 개수·타입이 .metal 과 어긋나면 여기서 던진다 — 테스트가 이걸로 서명을 지킨다.
    static func compileShader() async throws {
        let shader = ShaderLibrary.softPebble(
            .float2(1, 1), .float4(1, 0, 0.2, 1), .float4(1, 0, 1, 0), .float4(1, 0, 0, 0),
            .float4(0, 0, 1, 1), .float4(0, 0, 0, 0),
            .floatArray(SoftPebbleUniforms.table([0, 0.5, 0.5, 0.5])))
        try await shader.compile(as: .colorEffect)
    }

    /// 끝으로 갈수록 흐려진다 — 0·1 에서 0
    private var sheenAmount: Float {
        guard sheen > 0, sheen < 1 else { return 0 }
        return Float(min(1, min(sheen, 1 - sheen) / 0.20))
    }

    static func floats(_ stops: [DayGradient.Stop]) -> [Float] {
        stops.flatMap { stop -> [Float] in
            var v: UInt64 = 0
            let hex = stop.hex.hasPrefix("#") ? String(stop.hex.dropFirst()) : stop.hex
            guard hex.count == 6, Scanner(string: hex).scanHexInt64(&v) else {
                return [Float(stop.location), 0.5, 0.5, 0.5]
            }
            return [Float(stop.location),
                    Float((v >> 16) & 0xFF) / 255, Float((v >> 8) & 0xFF) / 255, Float(v & 0xFF) / 255]
        }
    }
}
