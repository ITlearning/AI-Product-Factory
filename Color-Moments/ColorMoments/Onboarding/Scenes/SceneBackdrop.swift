import SwiftUI

/// 온보딩 배경 색 — 화면과 떼어 둔 순수 판정.
enum BackdropPalette {

    typealias RGB = ColorExtractor.RGB

    static let maxDays = 4
    static let maxColors = 4

    /// 이미 받은 조약돌의 색만 쓴다 — 받기 전 하루의 색은 증정에서 처음 열려야 한다.
    static func sourceHexes(dayKeys: [String], isGifted: (String) -> Bool,
                            pebbleHexes: (String) -> [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for day in dayKeys.filter(isGifted).prefix(maxDays) {
            for hex in pebbleHexes(day) where result.count < maxColors && seen.insert(hex.uppercased()).inserted {
                result.append(hex)
            }
        }
        return result.isEmpty ? Tone.backdropWarm : result
    }

    static func sourceHexes(store: DayStore, gifts: GiftLog) -> [String] {
        sourceHexes(dayKeys: store.dayKeys, isGifted: gifts.isGifted,
                    pebbleHexes: { store.pebbleMoments(on: $0).map(\.colorHex) })
    }

    /// 어두운 쪽 — 채도를 낮추고 밝기를 눌러 흰 글자(Tone.secondary) 대비 4.5:1 을 지킨다.
    static func dark(_ hexes: [String]) -> [RGB] {
        tones(hexes) { h, s, v in hsv(h, min(s * 0.55, 0.42), min(max(v * 0.5, 0.10), 0.22)) }
    }

    static func tones(_ hexes: [String], _ map: (Double, Double, Double) -> RGB) -> [RGB] {
        let rgbs = hexes.compactMap(PebbleNaming.rgb(fromHex:))
        let source = rgbs.isEmpty ? Tone.backdropWarm.compactMap(PebbleNaming.rgb(fromHex:)) : rgbs
        return source.map { map(PebbleNaming.hue($0), PebbleNaming.saturation($0), PebbleNaming.value($0)) }
    }

    /// 3×3 격자 색. 아래 줄은 더 어둡게 — 글·버튼이 놓이는 자리다.
    static func mesh(_ tones: [RGB], bottom: Double) -> [RGB] {
        let t = (0..<maxColors).map { tones.isEmpty ? RGB(r: 0, g: 0, b: 0) : tones[$0 % tones.count] }
        func scaled(_ c: RGB, _ k: Double) -> RGB { RGB(r: c.r * k, g: c.g * k, b: c.b * k) }
        return [t[0], t[1], t[2],
                t[3], scaled(t[0], 0.85), t[1],
                scaled(t[2], bottom), scaled(t[3], bottom * 0.8), scaled(t[1], bottom)]
    }

    /// 격자 점 — 모서리는 고정, 나머지는 서로 다른 주기의 사인 곡선으로 아주 천천히 흐른다.
    static func points(at t: Double) -> [SIMD2<Float>] {
        func wave(_ period: Double, _ amp: Double, phase: Double = 0) -> Float {
            Float(amp * sin(t * 2 * .pi / period + phase))
        }
        return [
            [0, 0], [0.5 + wave(23, 0.14), 0], [1, 0],
            [0, 0.5 + wave(29, 0.10)], [0.5 + wave(31, 0.16, phase: 1), 0.45 + wave(37, 0.12, phase: 2)],
            [1, 0.5 + wave(26, 0.10, phase: 3)],
            [0, 1], [0.5 + wave(33, 0.14, phase: 4), 1], [1, 1],
        ]
    }

    static func hsv(_ h: Double, _ s: Double, _ v: Double) -> RGB {
        let c = v * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        let (r, g, b): (Double, Double, Double) = switch h {
        case ..<60: (c, x, 0)
        case ..<120: (x, c, 0)
        case ..<180: (0, c, x)
        case ..<240: (0, x, c)
        case ..<300: (x, 0, c)
        default: (c, 0, x)
        }
        return RGB(r: r + m, g: g + m, b: b + m)
    }

    // MARK: 대비 (WCAG)

    static func luminance(_ c: RGB) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    /// 반투명 글자를 배경 위에 얹은 실제 색으로 잰 대비.
    static func contrast(text: RGB, alpha: Double, over bg: RGB) -> Double {
        let mixed = RGB(r: text.r * alpha + bg.r * (1 - alpha),
                        g: text.g * alpha + bg.g * (1 - alpha),
                        b: text.b * alpha + bg.b * (1 - alpha))
        let a = luminance(mixed), b = luminance(bg)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// 온보딩 장면이 지금 움직여도 되는지 — 커버가 덮였거나 앱이 뒤로 가면 멈춘다.
private struct ScenesPausedKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var onboardingScenesPaused: Bool {
        get { self[ScenesPausedKey.self] }
        set { self[ScenesPausedKey.self] = newValue }
    }
}

/// 장면용 시계 — 동작 줄이기·멈춤이면 서 있고, 움직일 땐 초당 30장을 넘지 않는다.
struct SceneClock<Content: View>: View {
    @ViewBuilder let content: (_ t: Double, _ moving: Bool) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingScenesPaused) private var paused
    @Environment(\.scenePhase) private var scenePhase
    @State private var origin = Date()

    private var moving: Bool { !reduceMotion && !paused && scenePhase == .active }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !moving)) { context in
            content(reduceMotion ? 0 : context.date.timeIntervalSince(origin), moving)
        }
    }
}

struct SceneBackdrop: View {
    let hexes: [String]

    var body: some View {
        let colors = BackdropPalette.mesh(BackdropPalette.dark(hexes), bottom: 0.45)
            .map { Color(red: $0.r, green: $0.g, blue: $0.b) }
        SceneClock { t, _ in
            MeshGradient(width: 3, height: 3, points: BackdropPalette.points(at: t), colors: colors)
        }
        .background(Tone.base)
        .ignoresSafeArea()
    }
}
