import SwiftUI

public enum SceneKind: String, CaseIterable, Codable, Sendable {
    case sun, dawn, dusk, stars, moon, rain, drizzle, snow, fog, wind, petals, leaves, frost
}

/// wash = watercolor sky (default, app cards always), print = black ground with lines and one accent dot.
public enum SceneStyle: String, CaseIterable, Codable, Sendable {
    case wash, print
}

public struct SceneRGB: Equatable, Sendable {
    public let r: Double, g: Double, b: Double

    public init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    public init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        guard s.count == 6, Scanner(string: s).scanHexInt64(&v) else { self.init(0.5, 0.5, 0.5); return }
        self.init(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    public static let white = SceneRGB(1, 1, 1)

    public var color: Color { Color(red: r, green: g, blue: b) }

    /// self painted with `alpha` over `base`, in sRGB like the renderer.
    public func over(_ base: SceneRGB, alpha: Double) -> SceneRGB {
        SceneRGB(r * alpha + base.r * (1 - alpha), g * alpha + base.g * (1 - alpha), b * alpha + base.b * (1 - alpha))
    }

    func mixed(with o: SceneRGB, _ t: Double) -> SceneRGB { o.over(self, alpha: t) }

    func scaled(_ k: Double) -> SceneRGB { SceneRGB(r * k, g * k, b * k) }

    public var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    public static func contrast(_ a: SceneRGB, _ b: SceneRGB) -> Double {
        let (lo, hi) = (min(a.luminance, b.luminance), max(a.luminance, b.luminance))
        return (hi + 0.05) / (lo + 0.05)
    }
}

public struct SceneStop: Equatable, Sendable {
    public let at: Double
    public let color: SceneRGB
}

/// Full-width band whose alpha follows `alphas` (y, alpha) top to bottom; clamps past the ends like a gradient.
public struct SceneWash: Equatable, Sendable {
    public let color: SceneRGB
    public let alphas: [SIMD2<Double>]

    func alpha(at y: Double) -> Double {
        guard let first = alphas.first, let last = alphas.last else { return 0 }
        if y <= first.x { return first.y }
        if y >= last.x { return last.y }
        for (a, b) in zip(alphas, alphas.dropFirst()) where y <= b.x {
            return b.x > a.x ? a.y + (b.y - a.y) * (y - a.x) / (b.x - a.x) : b.y
        }
        return last.y
    }
}

public struct ScenePalette: Equatable, Sendable {
    public let sky: [SceneStop]
    public let washes: [SceneWash]
    /// The one colored mark in print style; nil = white only.
    public let accent: SceneRGB?
}

public struct SceneParticles: Equatable, Sendable {
    public var rain = 0, stars = 0, flakes = 0
}

public enum SceneArt {

    public static let printGround = SceneRGB(hex: "#0E1013")

    public static let rainCap = 30
    public static let starCap = 20

    /// Scene time used for a still picture (widget, reduce motion) — chosen so drops sit mid-fall.
    public static let stillPhase: Double = 7.3

    /// Photo tint share mixed into the sky — never lets a stop get brighter than the plain sky.
    public static let tintShare = 0.18

    private static func stops(_ s: [(Double, String)]) -> [SceneStop] {
        s.map { SceneStop(at: $0.0, color: SceneRGB(hex: $0.1)) }
    }

    private static func wash(_ hex: String, _ a: [(Double, Double)]) -> SceneWash {
        SceneWash(color: SceneRGB(hex: hex), alphas: a.map { SIMD2($0.0, $0.1) })
    }

    public static func palette(_ kind: SceneKind, _ style: SceneStyle) -> ScenePalette {
        let accent = accentHex(kind).map(SceneRGB.init(hex:))
        guard style == .wash else {
            return ScenePalette(sky: [SceneStop(at: 0, color: printGround)], washes: [], accent: accent)
        }
        let mist = "#B4C8D7"
        let fogTint = "#DCE4E8"
        switch kind {
        case .sun:
            return ScenePalette(sky: stops([(0, "#2A2218"), (1, "#3A2F20")]), washes: [], accent: accent)
        case .dawn:
            return ScenePalette(sky: stops([(0, "#0E1330"), (0.7, "#272950"), (1, "#34305A")]),
                                washes: [wash("#968CC8", [(0.55, 0), (1, 0.18)])], accent: accent)
        case .dusk:
            return ScenePalette(sky: stops([(0, "#2A1E2E"), (0.8, "#482A34"), (1, "#5E3430")]),
                                washes: [wash("#C7684A", [(0.55, 0), (0.95, 0.2)]),
                                         wash("#1A1214", [(0.949, 0), (0.95, 1)])], accent: accent)
        case .stars:
            return ScenePalette(sky: stops([(0, "#05070F"), (1, "#0E1328")]), washes: [], accent: accent)
        case .moon:
            return ScenePalette(sky: stops([(0, "#070A18"), (1, "#141A3A")]), washes: [], accent: accent)
        case .rain:
            return ScenePalette(sky: stops([(0, "#1C2830"), (1, "#2A3A44")]),
                                washes: [wash(mist, [(0.35, 0), (0.6, 0.12), (0.85, 0)])], accent: accent)
        case .drizzle:
            return ScenePalette(sky: stops([(0, "#1F272C"), (1, "#2E3A41")]),
                                washes: [wash(mist, [(0.3, 0), (0.55, 0.14), (0.8, 0.08), (1, 0.12)])], accent: accent)
        case .snow:
            return ScenePalette(sky: stops([(0, "#182030"), (1, "#2A3444")]), washes: [], accent: accent)
        case .fog:
            return ScenePalette(sky: stops([(0, "#20262B"), (1, "#30373C")]),
                                washes: [wash(fogTint, [(0.25, 0), (0.38, 0.1), (0.5, 0)]),
                                         wash(fogTint, [(0.5, 0), (0.65, 0.12), (0.8, 0)]),
                                         wash(fogTint, [(0.78, 0), (0.92, 0.12), (1, 0.06)])], accent: accent)
        case .wind:
            return ScenePalette(sky: stops([(0, "#1E2622"), (1, "#2B3530")]), washes: [], accent: accent)
        case .petals:
            return ScenePalette(sky: stops([(0, "#281E2C"), (1, "#3C2B3A")]), washes: [], accent: accent)
        case .leaves:
            return ScenePalette(sky: stops([(0, "#281F17"), (1, "#3A2C1E")]), washes: [], accent: accent)
        case .frost:
            return ScenePalette(sky: stops([(0, "#131B25"), (1, "#22303C")]),
                                washes: [wash("#C8DCEB", [(0.8, 0), (1, 0.1)])], accent: accent)
        }
    }

    static func accentHex(_ kind: SceneKind) -> String? {
        switch kind {
        case .sun: "#E8B860"
        case .dawn: "#9A94D0"
        case .dusk: "#E08A62"
        case .stars: "#F2D27A"
        case .petals: "#E8A4B4"
        case .leaves: "#D9904E"
        case .moon, .rain, .drizzle, .snow, .fog, .wind, .frost: nil
        }
    }

    public static func particles(_ kind: SceneKind) -> SceneParticles {
        switch kind {
        case .rain: SceneParticles(rain: 26)
        case .drizzle: SceneParticles(rain: 30)
        case .stars: SceneParticles(stars: 20)
        case .moon: SceneParticles(stars: 12)
        case .dawn: SceneParticles(stars: 12)
        case .snow: SceneParticles(flakes: 30)
        case .petals: SceneParticles(flakes: 16)
        case .leaves: SceneParticles(flakes: 12)
        case .wind: SceneParticles(flakes: 5)
        case .frost: SceneParticles(flakes: 5)
        case .sun, .dusk, .fog: SceneParticles()
        }
    }

    /// Sky stops with an optional photo color mixed in, clamped so no stop gets lighter.
    public static func sky(_ kind: SceneKind, _ style: SceneStyle, tintHex: String? = nil) -> [SceneStop] {
        let base = palette(kind, style).sky
        guard style == .wash, let tintHex else { return base }
        let tint = SceneRGB(hex: tintHex)
        return base.map { s in
            let mixed = s.color.mixed(with: tint, tintShare)
            guard mixed.luminance > s.color.luminance else { return SceneStop(at: s.at, color: mixed) }
            var lo = 0.0, hi = 1.0
            for _ in 0..<24 {
                let mid = (lo + hi) / 2
                if mixed.scaled(mid).luminance > s.color.luminance { hi = mid } else { lo = mid }
            }
            return SceneStop(at: s.at, color: mixed.scaled(lo))
        }
    }

    static func sample(_ stops: [SceneStop], _ y: Double) -> SceneRGB {
        guard let first = stops.first, let last = stops.last else { return printGround }
        if y <= first.at { return first.color }
        if y >= last.at { return last.color }
        for (a, b) in zip(stops, stops.dropFirst()) where y <= b.at {
            let t = b.at > a.at ? (y - a.at) / (b.at - a.at) : 1
            return a.color.mixed(with: b.color, t)
        }
        return last.color
    }

    /// The color behind text at height y (0 top, 1 bottom) — sky plus full-width washes. Particles not included.
    public static func backdrop(_ kind: SceneKind, _ style: SceneStyle, y: Double, tintHex: String? = nil) -> SceneRGB {
        var c = sample(sky(kind, style, tintHex: tintHex), y)
        for w in palette(kind, style).washes {
            c = w.color.over(c, alpha: w.alpha(at: y))
        }
        return c
    }

    /// Where card text sits, per card shape: square/hero = top label + word block; wide = word, date and two corner labels.
    public static func textRects(in size: CGSize) -> [CGRect] { Frame(size).texts }

    // MARK: geometry shared by drawing and bounds

    struct Frame {
        let w: CGFloat, h: CGFloat
        var u: CGFloat { min(w, h) }
        init(_ size: CGSize) { w = size.width; h = size.height }

        var wide: Bool { w > 1.8 * h }
        var hero: Bool { !wide && w > 1.3 * h }
        var blockRight: CGFloat { (hero ? 0.64 : 0.78) * w }
        var texts: [CGRect] {
            if wide {
                return [CGRect(x: 0, y: 0, width: 0.44 * w, height: 0.6 * h),
                        CGRect(x: 0, y: 0.6 * h, width: 0.36 * w, height: 0.32 * h),
                        CGRect(x: 0.78 * w, y: 0, width: 0.22 * w, height: 0.42 * h),
                        CGRect(x: 0.78 * w, y: 0.6 * h, width: 0.22 * w, height: 0.32 * h)]
            }
            return [CGRect(x: 0, y: 0, width: 0.55 * w, height: 0.22 * h),
                    CGRect(x: 0, y: 0.5 * h, width: blockRight, height: 0.43 * h)]
        }
        /// Text-free room for bright marks: the middle column on wide cards, the top right elsewhere.
        var pane: CGRect {
            wide ? CGRect(x: 0.46 * w, y: 0, width: 0.3 * w, height: h)
                 : CGRect(x: 0.58 * w, y: 0, width: 0.42 * w, height: 0.48 * h)
        }
        var feather: CGFloat { 0.06 * u }
        var horizon: CGFloat { 0.95 * h }

        /// A mark sitting on the bottom edge: in the pane on wide cards, else right of the word block (shrunk to fit).
        func bottomMark(_ x: CGFloat, _ r: CGFloat) -> (x: CGFloat, r: CGFloat) {
            if wide { return (pane.midX, min(r, pane.width / 2)) }
            let limit = blockRight + 0.02 * w
            let cx = max(x, limit + r)
            return cx <= w ? (cx, r) : (w, w - limit)
        }

        var sun: (c: CGPoint, r: CGFloat) { (CGPoint(x: wide ? pane.midX : w - 0.12 * u, y: 0.12 * u), 0.3 * u) }
        var moon: (c: CGPoint, r: CGFloat, halo: CGFloat) {
            (wide ? CGPoint(x: pane.midX, y: 0.5 * h) : CGPoint(x: w - 0.22 * u, y: 0.24 * u), 0.12 * u, 0.2 * u)
        }
        var duskSun: (c: CGPoint, r: CGFloat, glow: CGFloat) {
            let (x, g) = bottomMark(w - 0.12 * u, 0.2 * u)
            return (CGPoint(x: x, y: horizon), 0.6 * g, g)
        }
        var dawnGlow: (c: CGPoint, r: CGFloat) {
            let (x, r) = bottomMark(w - 0.2 * u, 0.22 * u * 1.05)
            return (CGPoint(x: x, y: h), r / 1.05)
        }
        var horizonStart: CGFloat { wide ? pane.minX : 0.58 * w }
        var frostArea: CGRect {
            wide ? CGRect(x: pane.minX, y: 0.1 * h, width: pane.width, height: 0.8 * h)
                 : CGRect(x: 0.62 * w, y: 0.06 * h, width: 0.34 * w, height: 0.4 * h)
        }
        func paneY(_ k: CGFloat) -> CGFloat { pane.minY + pane.height * k }
    }

    /// Bright marks and lines (sun, moon, glow, horizon, wind and fog lines, frost) — must stay out of every text rect.
    public static func brightBounds(_ kind: SceneKind, _ style: SceneStyle, in size: CGSize) -> [CGRect] {
        let f = Frame(size)
        func box(_ c: CGPoint, _ r: CGFloat) -> CGRect { CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r) }
        switch kind {
        case .sun: return [f.pane]
        case .moon: return [box(f.moon.c, f.moon.halo * 1.03)]
        case .dusk:
            let (c, r, g) = f.duskSun
            return [CGRect(x: c.x - g, y: c.y - 0.55 * r - g, width: 2 * g, height: 0.55 * r + g),
                    CGRect(x: f.horizonStart, y: f.horizon - 1, width: f.w - f.horizonStart, height: 2),
                    CGRect(x: c.x - 1.1 * r, y: f.horizon, width: 2.2 * r, height: f.h - f.horizon)]
        case .dawn: return [box(f.dawnGlow.c, f.dawnGlow.r * 1.05), CGRect(x: f.w * 0.6, y: f.h - 1, width: f.w * 0.4, height: 1)]
        case .wind, .fog: return [f.pane]
        case .frost: return [f.frostArea]
        case .stars, .rain, .drizzle, .snow, .petals, .leaves: return []
        }
    }

    // MARK: drawing

    static func rnd(_ i: Int, _ k: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return v - floor(v)
    }

    static func frac(_ x: Double) -> Double { x - floor(x) }

    /// Particle opacity factor: 0 when its box touches a text rect, easing to 1 one feather away.
    static func clear(_ box: CGRect, _ f: Frame) -> Double {
        let b = box.insetBy(dx: -1, dy: -1)
        let d = f.texts.map { r -> CGFloat in
            hypot(max(0, r.minX - b.maxX, b.minX - r.maxX), max(0, r.minY - b.maxY, b.minY - r.maxY))
        }.min() ?? .infinity
        let t = Double(min(1, d / f.feather))
        return t * t * (3 - 2 * t)
    }

    static func dot(_ c: CGPoint, _ r: CGFloat) -> CGRect { CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r) }

    public static func draw(_ kind: SceneKind, _ style: SceneStyle, t: Double, tintHex: String? = nil,
                            marks: Bool = true, in ctx: inout GraphicsContext, size: CGSize) {
        let f = Frame(size)
        let rect = CGRect(origin: .zero, size: size)
        let skyStops = Self.sky(kind, style, tintHex: tintHex)
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(stops: skyStops.map { .init(color: $0.color.color, location: $0.at) }),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        let pal = palette(kind, style)
        for w in pal.washes {
            ctx.fill(Path(rect), with: .linearGradient(
                Gradient(stops: w.alphas.map { .init(color: w.color.color.opacity($0.y), location: $0.x) }),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        }
        guard marks else { return }
        let print = style == .print
        let ink = SceneRGB.white
        let accent = pal.accent ?? ink

        switch kind {
        case .sun: drawSun(f, t, print, accent, &ctx)
        case .dawn:
            drawStars(f, t, particles(kind).stars, top: 0.5, ink, accentFirst: nil, &ctx)
            drawDawn(f, t, print, accent, &ctx)
        case .dusk: drawDusk(f, t, print, accent, &ctx)
        case .stars: drawStars(f, t, particles(kind).stars, top: 0.62, ink, accentFirst: print ? accent : nil, &ctx)
        case .moon:
            drawStars(f, t, particles(kind).stars, top: 0.62, ink, accentFirst: nil, &ctx)
            drawMoon(f, t, print, &ctx)
        case .rain: drawRain(f, t, particles(kind).rain, fine: false, print, &ctx)
        case .drizzle: drawRain(f, t, particles(kind).rain, fine: true, print, &ctx)
        case .snow: drawSnow(f, t, particles(kind).flakes, print, &ctx)
        case .fog: drawFog(f, t, print, &ctx)
        case .wind: drawWind(f, t, particles(kind).flakes, print, &ctx)
        case .petals: drawFalling(f, t, particles(kind).flakes, leaf: false, print, accent, &ctx)
        case .leaves: drawFalling(f, t, particles(kind).flakes, leaf: true, print, accent, &ctx)
        case .frost: drawFrost(f, t, particles(kind).flakes, print, &ctx)
        }
    }

    private static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    private static func glow(_ c: CGPoint, _ r: CGFloat, _ stops: [(SceneRGB, Double, CGFloat)]) -> GraphicsContext.Shading {
        .radialGradient(Gradient(stops: stops.map { .init(color: $0.0.color.opacity($0.1), location: $0.2) }),
                        center: c, startRadius: 0, endRadius: r)
    }

    private static func breathe(_ t: Double, period: Double, depth: Double) -> CGFloat {
        CGFloat(1 + depth * sin(2 * .pi * t / period))
    }

    private static func drawSun(_ f: Frame, _ t: Double, _ print: Bool, _ accent: SceneRGB, _ ctx: inout GraphicsContext) {
        let (c, r) = f.sun
        let k = breathe(t, period: 5, depth: 0.04)
        var clip = ctx
        clip.clip(to: Path(f.pane))
        if print {
            clip.stroke(circle(c, r * 0.36 * k), with: .color(accent.color), lineWidth: 1.5)
            for i in 0..<6 {
                let a = CGFloat(i) / 6 * 2 * .pi + .pi / 12
                let p0 = CGPoint(x: c.x + cos(a) * r * 0.52, y: c.y + sin(a) * r * 0.52)
                let p1 = CGPoint(x: c.x + cos(a) * r * 0.7, y: c.y + sin(a) * r * 0.7)
                var p = Path(); p.move(to: p0); p.addLine(to: p1)
                clip.stroke(p, with: .color(.white.opacity(0.5)), lineWidth: 1)
            }
            return
        }
        clip.fill(circle(c, r * k), with: glow(c, r * k, [
            (SceneRGB(hex: "#FFE6A8"), 1, 0), (SceneRGB(hex: "#FFD68C"), 0.55, 0.38), (SceneRGB(hex: "#FFD68C"), 0, 1)]))
        for (i, degrees) in [128.0, 148.0].enumerated() {
            let pulse = 0.25 + 0.35 * (0.5 - 0.5 * cos(2 * .pi * (t / 4 + Double(i) * 0.35)))
            let a = CGFloat(degrees) * .pi / 180
            let p0 = CGPoint(x: c.x + cos(a) * r * 0.4, y: c.y + sin(a) * r * 0.4)
            let p1 = CGPoint(x: c.x + cos(a) * f.u * 0.55, y: c.y + sin(a) * f.u * 0.55)
            var p = Path(); p.move(to: p0); p.addLine(to: p1)
            clip.stroke(p, with: .linearGradient(Gradient(colors: [.clear, Color(red: 1, green: 0.9, blue: 0.67).opacity(pulse), .clear]),
                                                 startPoint: p0, endPoint: p1), lineWidth: 1.5)
        }
    }

    private static func drawMoon(_ f: Frame, _ t: Double, _ print: Bool, _ ctx: inout GraphicsContext) {
        let (c, r, halo) = f.moon
        let k = breathe(t, period: 5, depth: 0.03)
        if print {
            ctx.stroke(circle(c, r * k), with: .color(.white.opacity(0.85)), lineWidth: 1.5)
            ctx.stroke(circle(c, halo * 0.92), with: .color(.white.opacity(0.25)), lineWidth: 1)
            return
        }
        let haze = SceneRGB(hex: "#F0E8C8")
        ctx.fill(circle(c, halo * k), with: glow(c, halo * k, [(haze, 0.3, r / halo), (haze, 0, 1)]))
        ctx.fill(circle(c, r), with: .radialGradient(
            Gradient(stops: [.init(color: SceneRGB(hex: "#FBF6E4").color, location: 0),
                             .init(color: SceneRGB(hex: "#E6DFC4").color, location: 0.6),
                             .init(color: SceneRGB(hex: "#CFC7A8").color, location: 1)]),
            center: CGPoint(x: c.x - r * 0.2, y: c.y - r * 0.24), startRadius: 0, endRadius: r * 1.2))
    }

    private static func drawDusk(_ f: Frame, _ t: Double, _ print: Bool, _ accent: SceneRGB, _ ctx: inout GraphicsContext) {
        let (c0, r, g) = f.duskSun
        let c = CGPoint(x: c0.x, y: c0.y - r * 0.35 + r * 0.2 * CGFloat(sin(2 * .pi * t / 12)))
        var sky = ctx
        sky.clip(to: Path(CGRect(x: 0, y: 0, width: f.w, height: f.horizon)))
        let x0 = f.horizonStart
        let line = Path { p in p.move(to: CGPoint(x: x0, y: f.horizon)); p.addLine(to: CGPoint(x: f.w, y: f.horizon)) }
        let fade = Gradient(colors: [.clear, .white.opacity(print ? 0.7 : 0.4)])
        if print {
            sky.stroke(circle(c, r), with: .color(accent.color), lineWidth: 1.5)
        } else {
            sky.fill(circle(c, g), with: glow(c, g, [(SceneRGB(hex: "#F2A06E"), 1, 0), (SceneRGB(hex: "#D9744C"), 1, 0.55),
                                                     (SceneRGB(hex: "#D9744C"), 0, 1)]))
        }
        ctx.stroke(line, with: .linearGradient(fade, startPoint: CGPoint(x: x0, y: 0), endPoint: CGPoint(x: f.w * 0.85, y: 0)),
                   lineWidth: 1)
        guard print else { return }
        let step = max(2, (f.h - f.horizon) / 4)
        for i in 1...3 where f.horizon + CGFloat(i) * step < f.h {
            let y = f.horizon + CGFloat(i) * step
            let half = r * (1.4 - CGFloat(i) * 0.3)
            var p = Path(); p.move(to: CGPoint(x: c0.x - half, y: y)); p.addLine(to: CGPoint(x: c0.x + half, y: y))
            ctx.stroke(p, with: .color(.white.opacity(0.55 - Double(i) * 0.12)), lineWidth: 1)
        }
    }

    private static func drawDawn(_ f: Frame, _ t: Double, _ print: Bool, _ accent: SceneRGB, _ ctx: inout GraphicsContext) {
        let (c, r) = f.dawnGlow
        let k = breathe(t, period: 7, depth: 0.05)
        if print {
            var arc = Path()
            arc.addArc(center: c, radius: r * 0.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            ctx.stroke(arc, with: .color(accent.color), lineWidth: 1.5)
            var line = Path(); line.move(to: CGPoint(x: f.w * 0.6, y: f.h - 0.5)); line.addLine(to: CGPoint(x: f.w, y: f.h - 0.5))
            ctx.stroke(line, with: .color(.white.opacity(0.6)), lineWidth: 1)
            return
        }
        let lav = SceneRGB(hex: "#B8B0E8")
        ctx.fill(circle(c, r * k), with: glow(c, r * k, [(lav, 0.5, 0), (lav, 0, 1)]))
    }

    private static func drawStars(_ f: Frame, _ t: Double, _ n: Int, top: CGFloat, _ ink: SceneRGB,
                                  accentFirst: SceneRGB?, _ ctx: inout GraphicsContext) {
        let scale = max(1, f.u / 170)
        for i in 0..<min(n, starCap) {
            let x = CGFloat(rnd(i, 5)) * f.w
            let y = CGFloat(rnd(i, 6)) * f.h * top
            let big = rnd(i, 7) > 0.8 || (accentFirst != nil && i == 0)
            let r = (big ? 1.25 : 0.75) * scale
            let dur = 2 + rnd(i, 8) * 3
            let tw = 0.12 + 0.83 * (0.5 - 0.5 * cos(2 * .pi * (t / dur + rnd(i, 9))))
            let color = i == 0 ? (accentFirst ?? ink) : ink
            ctx.fill(circle(CGPoint(x: x, y: y), r), with: .color(color.color.opacity(tw * clear(dot(CGPoint(x: x, y: y), r), f))))
        }
    }

    private static func drawRain(_ f: Frame, _ t: Double, _ n: Int, fine: Bool, _ print: Bool, _ ctx: inout GraphicsContext) {
        let color = print ? SceneRGB.white : SceneRGB(hex: "#BED7EB")
        let peak = print ? (fine ? 0.85 : 0.55) : (fine ? 0.55 : 0.7)
        let slant: CGFloat = 0.06
        for i in 0..<min(n, rainCap) {
            let dur = fine ? 1.6 + rnd(i, 3) * 0.8 : 1.0 + rnd(i, 3) * 0.6
            let len = f.u * CGFloat(fine ? (print ? 0.05 : 0.035) + rnd(i, 2) * 0.03 : 0.07 + rnd(i, 2) * 0.06)
            let ph = CGFloat(frac(t / dur + rnd(i, 4)))
            let y = -len + ph * (f.h + 2 * len)
            let x = CGFloat(rnd(i, 1)) * (f.w + slant * f.h) - slant * y
            let p0 = CGPoint(x: x, y: y), p1 = CGPoint(x: x - slant * len, y: y + len)
            var p = Path(); p.move(to: p0); p.addLine(to: p1)
            let a = peak * clear(CGRect(x: p1.x, y: p0.y, width: p0.x - p1.x, height: len), f)
            ctx.stroke(p, with: .linearGradient(Gradient(colors: [color.color.opacity(print && fine ? 0.25 * a : 0), color.color.opacity(a)]),
                                                startPoint: p0, endPoint: p1),
                       style: StrokeStyle(lineWidth: fine ? (print ? 1.2 : 0.8) : 1, lineCap: .round))
        }
    }

    private static func drawSnow(_ f: Frame, _ t: Double, _ n: Int, _ print: Bool, _ ctx: inout GraphicsContext) {
        let scale = max(1, f.u / 170)
        for i in 0..<n {
            let dur = 5 + rnd(i, 3) * 4
            let ph = CGFloat(frac(t / dur + rnd(i, 4)))
            let y = -4 + ph * (f.h + 8)
            let x = CGFloat(rnd(i, 1)) * f.w + f.u * 0.03 * CGFloat(sin(t * 0.9 + Double(i)))
            let r = CGFloat(0.8 + rnd(i, 2) * 1.2) * scale
            ctx.fill(circle(CGPoint(x: x, y: y), r), with: .color(.white.opacity((print ? 0.7 : 0.85) * clear(dot(CGPoint(x: x, y: y), r), f))))
        }
    }

    private static func drawFog(_ f: Frame, _ t: Double, _ print: Bool, _ ctx: inout GraphicsContext) {
        var pane = ctx
        pane.clip(to: Path(f.pane))
        for (i, y) in [0.25, 0.55, 0.85].enumerated() {
            let drift = f.u * 0.08 * CGFloat(sin(2 * .pi * t / 9 + Double(i) * 1.7))
            let cy = f.paneY(CGFloat(y))
            if print {
                let x0 = f.pane.minX + drift
                var p = Path(); p.move(to: CGPoint(x: x0, y: cy)); p.addLine(to: CGPoint(x: f.w + f.u * 0.1, y: cy))
                pane.stroke(p, with: .color(.white.opacity(0.35)),
                            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [f.u * 0.08, f.u * 0.05],
                                               dashPhase: CGFloat(t * 6)))
            } else {
                let c = CGPoint(x: f.pane.minX + f.pane.width * 0.6 + drift, y: cy)
                let r = f.u * 0.3
                var wisp = pane
                wisp.scaleBy(x: 1, y: 0.35)
                let cc = CGPoint(x: c.x, y: c.y / 0.35)
                wisp.fill(circle(cc, r), with: glow(cc, r, [(SceneRGB(hex: "#DCE4E8"), 0.14, 0), (SceneRGB(hex: "#DCE4E8"), 0, 1)]))
            }
        }
    }

    private static func drawWind(_ f: Frame, _ t: Double, _ n: Int, _ print: Bool, _ ctx: inout GraphicsContext) {
        var pane = ctx
        pane.clip(to: Path(f.pane))
        for (i, y) in [0.3, 0.58, 0.86].enumerated() {
            let sway = f.w * 0.03 * CGFloat(sin(2 * .pi * t / 5 + Double(i) * 1.2))
            let p0 = CGPoint(x: f.pane.minX + f.u * 0.05 + sway, y: f.paneY(CGFloat(y)))
            let p1 = CGPoint(x: f.pane.maxX + (f.wide ? 0 : f.u * 0.05), y: p0.y - f.u * 0.05)
            var p = Path()
            p.move(to: p0)
            p.addQuadCurve(to: p1, control: CGPoint(x: (p0.x + p1.x) / 2, y: p0.y + f.u * 0.08))
            let a = print ? 0.6 : 0.35 - Double(i) * 0.05
            pane.stroke(p, with: .linearGradient(Gradient(colors: [.clear, .white.opacity(a), .clear]), startPoint: p0, endPoint: p1),
                        lineWidth: 1)
        }
        for i in 0..<n {
            let dur = 3 + rnd(i, 3) * 2
            let ph = CGFloat(frac(t / dur + rnd(i, 4)))
            let x = -f.u * 0.05 + ph * (f.w + f.u * 0.1)
            let y = f.h * CGFloat(0.2 + rnd(i, 2) * 0.6) + f.u * 0.04 * CGFloat(sin(Double(ph) * 2 * .pi))
            ctx.fill(circle(CGPoint(x: x, y: y), 1), with: .color(.white.opacity(0.5 * clear(dot(CGPoint(x: x, y: y), 1), f))))
        }
    }

    private static func drawFalling(_ f: Frame, _ t: Double, _ n: Int, leaf: Bool, _ print: Bool, _ accent: SceneRGB,
                                    _ ctx: inout GraphicsContext) {
        let tones = leaf ? [SceneRGB(hex: "#C98A4A"), SceneRGB(hex: "#A8683A")] : [SceneRGB(hex: "#E8B4C0"), SceneRGB(hex: "#D69AAE")]
        let size = f.u * (leaf ? 0.05 : 0.032)
        for i in 0..<n {
            let dur = leaf ? 7 + rnd(i, 3) * 4 : 6 + rnd(i, 3) * 4
            let ph = CGFloat(frac(t / dur + rnd(i, 4)))
            let y = -size + ph * (f.h + 2 * size)
            let x = CGFloat(rnd(i, 1)) * (f.w + f.u * 0.3) - ph * f.u * 0.3 + f.u * 0.04 * CGFloat(sin(t * 1.3 + Double(i)))
            let angle = t * (0.6 + rnd(i, 5)) + rnd(i, 6) * 6.3
            let shape: Path
            if leaf {
                shape = Path { p in
                    p.move(to: CGPoint(x: -size, y: 0))
                    p.addQuadCurve(to: CGPoint(x: size, y: 0), control: CGPoint(x: 0, y: -size * 0.7))
                    p.addQuadCurve(to: CGPoint(x: -size, y: 0), control: CGPoint(x: 0, y: size * 0.7))
                }
            } else {
                shape = Path(ellipseIn: CGRect(x: -size, y: -size * 0.55, width: 2 * size, height: 1.1 * size))
            }
            let placed = shape.applying(CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: x, y: y)))
            let d = clear(placed.boundingRect, f)
            if print {
                if i == 0 {
                    ctx.fill(placed, with: .color(accent.color.opacity(d)))
                } else {
                    ctx.stroke(placed, with: .color(.white.opacity(0.6 * d)), lineWidth: 0.8)
                }
            } else {
                ctx.fill(placed, with: .color(tones[i % 2].color.opacity(0.85 * d)))
            }
        }
    }

    private static func drawFrost(_ f: Frame, _ t: Double, _ n: Int, _ print: Bool, _ ctx: inout GraphicsContext) {
        let area = f.frostArea
        for i in 0..<n {
            let r = f.u * CGFloat(0.03 + rnd(i, 2) * 0.03)
            let c = CGPoint(x: area.minX + r + CGFloat(rnd(i, 1)) * (area.width - 2 * r),
                            y: area.minY + r + CGFloat(rnd(i, 3)) * (area.height - 2 * r))
            let tw = 0.3 + 0.5 * (0.5 - 0.5 * cos(2 * .pi * (t / (3 + rnd(i, 8) * 2) + rnd(i, 9))))
            var p = Path()
            for k in 0..<3 {
                let a = CGFloat(k) * .pi / 3 + CGFloat(rnd(i, 5))
                p.move(to: CGPoint(x: c.x - cos(a) * r, y: c.y - sin(a) * r))
                p.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
            }
            ctx.stroke(p, with: .color(.white.opacity(print ? tw * 0.9 : tw)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        }
    }
}

/// Scene time that survives pausing: stop holds the current moment, start continues from it.
public struct SceneTime: Equatable, Sendable {
    public private(set) var held: Double
    public private(set) var since: Date?

    public init(phase: Double) { held = phase }

    public func time(at date: Date) -> Double {
        guard let since else { return held }
        return held + max(0, date.timeIntervalSince(since))
    }

    public mutating func set(running: Bool, at date: Date) {
        if running {
            if since == nil { since = date }
        } else if let since {
            held += max(0, date.timeIntervalSince(since))
            self.since = nil
        }
    }
}

/// Decorative — hidden from VoiceOver; the caller reads the card as one element.
/// `animating` is the caller's switch (only cards on screen); widgets and reduce motion always get the still picture.
public struct SceneView: View {
    public static let heroFrameInterval: Double = 1.0 / 60
    public static let cardFrameInterval: Double = 1.0 / 30

    private let kind: SceneKind
    private let style: SceneStyle
    private let animating: Bool
    private let frameInterval: Double
    private let tintHex: String?
    @State private var clock: SceneTime
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ kind: SceneKind, style: SceneStyle = .wash, animating: Bool = false,
                frameInterval: Double = SceneView.cardFrameInterval, phase: Double = SceneArt.stillPhase,
                tintHex: String? = nil) {
        self.kind = kind
        self.style = style
        self.animating = animating
        self.frameInterval = frameInterval
        self.tintHex = tintHex
        _clock = State(initialValue: SceneTime(phase: phase))
    }

    private var running: Bool { animating && !reduceMotion }

    public var body: some View {
        Group {
            if running {
                TimelineView(.animation(minimumInterval: frameInterval)) { timeline in
                    canvas(clock.time(at: timeline.date))
                }
            } else {
                canvas(clock.held)
            }
        }
        .onAppear { clock.set(running: running, at: Date()) }
        .onDisappear { clock.set(running: false, at: Date()) }
        .onChange(of: running) { _, now in clock.set(running: now, at: Date()) }
        .accessibilityHidden(true)
    }

    private func canvas(_ t: Double) -> some View {
        Canvas(opaque: true) { ctx, size in
            SceneArt.draw(kind, style, t: t, tintHex: tintHex, in: &ctx, size: size)
        }
    }
}
