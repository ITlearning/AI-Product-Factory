import SwiftUI
import WidgetKit

/// 홈 화면 작은 위젯 — 장면은 멈춘 그림, 글자는 SceneArt.textRects(네모) 안에만.
/// 왼쪽 위 라벨 자리에 줍기, 아래 덩어리에 말(명조)과 장면 문장 한 줄.
/// pick 은 부르는 쪽이 넣는다 — 위젯은 Button(intent:), 앱 미리보기는 그냥 모양.
public struct WordWidgetSmall<PickControl: View>: View {
    let model: WordWidgetModel
    let style: SceneStyle
    let text: WordWidgetText?
    /// 위젯은 containerBackground 로 장면을 깔고, 앱(미리보기·화면 덤프)은 직접 깐다.
    let drawsBackground: Bool
    let pick: (WordWidgetModel) -> PickControl

    public init(model: WordWidgetModel, style: SceneStyle, text: WordWidgetText? = WordWidgetText.cached,
                drawsBackground: Bool, @ViewBuilder pick: @escaping (WordWidgetModel) -> PickControl) {
        self.model = model
        self.style = style
        self.text = text
        self.drawsBackground = drawsBackground
        self.pick = pick
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                if drawsBackground { WordWidgetBackground(model: model, style: style) }
                if model.word != nil {
                    pickSlot
                        .frame(width: 0.55 * w - 12, height: 0.22 * h, alignment: .leading)
                        .padding(.leading, 12).padding(.top, 10)
                    block(w: w, h: h)
                } else {
                    Text(text?.brand ?? "").font(Face.word).foregroundStyle(Tone.secondary)
                        .frame(width: 0.78 * w - 16, height: 0.43 * h, alignment: .bottomLeading)
                        .padding(.leading, 16)
                        .offset(y: 0.5 * h)
                }
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    @ViewBuilder
    private var pickSlot: some View {
        switch model.pick {
        case .open:
            pick(model)
                .transition(.opacity)
        case .justPicked:
            HStack(spacing: 6) {
                WordPebbleMark()
                Text(text?.picked ?? "").font(Face.wordMeta).foregroundStyle(Tone.primary).lineLimit(1)
            }
            .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
        case .picked:
            WordPebbleMark()
                .padding(.leading, 4)
                .transition(.opacity)
        }
    }

    // 말·문장 덩어리 — 폭 78%, 높이 50~93%.
    private func block(w: CGFloat, h: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Spacer(minLength: 0)
            Text(model.word ?? "").font(Face.word).foregroundStyle(Tone.primary)
                .lineLimit(1).minimumScaleFactor(0.5)
            if let meaning = model.meaning {
                Text(meaning).font(Face.wordMeta)
                    .foregroundStyle(Tone.secondary)
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 0.78 * w - 16, height: 0.43 * h, alignment: .bottomLeading)
        .padding(.leading, 16)
        .offset(y: 0.5 * h)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.accessibilityText(text) ?? "")
    }
}

/// 장면 — 말을 못 읽었으면 바탕만.
public struct WordWidgetBackground: View {
    let model: WordWidgetModel
    let style: SceneStyle

    public init(model: WordWidgetModel, style: SceneStyle) {
        self.model = model
        self.style = style
    }

    public var body: some View {
        if let scene = model.scene {
            SceneView(scene, style: style)
        } else {
            Tone.base
        }
    }
}

/// 앱 미리보기용 줍기 모양 — 위젯은 같은 모양을 Button(intent:) 안에 넣는다.
public struct WordPickLabel: View {
    let title: String

    public init(_ title: String) { self.title = title }

    public var body: some View {
        Text(title).font(Face.wordMeta).foregroundStyle(Tone.primary)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(.white.opacity(0.14), in: Capsule())
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
    }
}

/// 주운 자리에 남는 작은 조약돌.
public struct WordPebbleMark: View {
    public init() {}
    public var body: some View {
        Ellipse().fill(Tone.secondary).frame(width: 16, height: 11.5)
            .rotationEffect(.degrees(-8))
            .accessibilityHidden(true)
    }
}

// MARK: - 잠금화면 — 한 가지 색으로 칠해진다. 색 대신 흰빛 밝기 단계로만.

/// 날짜 옆 한 줄 — 「밖에 '는개'」.
public struct WordLockInline: View {
    let model: WordWidgetModel
    let text: WordWidgetText?

    public init(model: WordWidgetModel, text: WordWidgetText? = WordWidgetText.cached) {
        self.model = model
        self.text = text
    }

    public var body: some View {
        Text(model.short ?? model.word ?? text?.brand ?? "")
    }
}

/// 동그란 칸 — 장면을 선과 점으로.
public struct WordLockCircular: View {
    let model: WordWidgetModel

    public init(model: WordWidgetModel) { self.model = model }

    public var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let scene = model.scene {
                LockSceneGlyph(scene: scene, moonAge: model.moonAge)
                    .padding(6)
            }
        }
    }
}

/// 네모 칸 — 말(명조) + 뜻.
public struct WordLockRectangular: View {
    let model: WordWidgetModel
    let text: WordWidgetText?

    public init(model: WordWidgetModel, text: WordWidgetText? = WordWidgetText.cached) {
        self.model = model
        self.text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.word ?? text?.brand ?? "").font(Face.wordLock)
                .lineLimit(1).minimumScaleFactor(0.6)
                .widgetAccentable()
            if let meaning = model.meaning {
                Text(meaning).font(Face.wordMeta).opacity(0.72)
                    .lineLimit(2).minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// 잠금화면 동그란 칸의 그림 — 빗줄기 사선, 빛무리 두른 달(달 나이대로 차고 기움), 반쪽 해 + 지평선 + 옅어지는 물결.
public struct LockSceneGlyph: View {
    let scene: SceneKind
    let moonAge: Double

    public init(scene: SceneKind, moonAge: Double) {
        self.scene = scene
        self.moonAge = moonAge
    }

    static let bright = 1.0, mid = 0.6, faint = 0.32

    public var body: some View {
        Canvas { ctx, size in Self.draw(scene, moonAge: moonAge, in: &ctx, size: size) }
            .accessibilityHidden(true)
    }

    static func draw(_ scene: SceneKind, moonAge: Double, in ctx: inout GraphicsContext, size: CGSize) {
        let u = min(size.width, size.height)
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        func ink(_ a: Double) -> GraphicsContext.Shading { .color(.white.opacity(a)) }
        func line(_ a: CGPoint, _ b: CGPoint, _ alpha: Double, _ width: CGFloat) {
            var p = Path(); p.move(to: a); p.addLine(to: b)
            ctx.stroke(p, with: ink(alpha), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        func dot(_ p: CGPoint, _ r: CGFloat, _ alpha: Double) {
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: ink(alpha))
        }
        func at(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: c.x + x * u, y: c.y + y * u) }

        switch scene {
        case .rain, .drizzle:
            let fine = scene == .drizzle
            let n = fine ? 9 : 7
            for i in 0..<n {
                let x = -0.36 + 0.72 * Double(i) / Double(n - 1)
                let y = SceneArt.rnd(i, 3) * 0.3 - 0.3
                let len = fine ? 0.14 : 0.24
                line(at(x + 0.05, y), at(x - 0.05, y + len), i % 3 == 0 ? bright : mid, fine ? 1.2 : 1.6)
            }
        case .snow:
            for i in 0..<10 {
                dot(at(SceneArt.rnd(i, 5) * 0.7 - 0.35, SceneArt.rnd(i, 9) * 0.7 - 0.35),
                    u * (0.022 + 0.02 * SceneArt.rnd(i, 2)), i % 3 == 0 ? bright : mid)
            }
        case .moon:
            let r = 0.2 * u
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 0.34 * u, y: c.y - 0.34 * u, width: 0.68 * u, height: 0.68 * u)),
                       with: ink(faint), lineWidth: 1)
            dot(c, r, 0.18)
            ctx.fill(moonLit(c, r, age: moonAge), with: ink(bright))
        case .sun:
            dot(c, 0.17 * u, bright)
            for i in 0..<8 {
                let a = Double(i) * .pi / 4
                line(at(cos(a) * 0.26, sin(a) * 0.26), at(cos(a) * 0.36, sin(a) * 0.36), mid, 1.4)
            }
        case .dusk, .dawn:
            let horizon = c.y + 0.06 * u
            var half = Path()
            half.addArc(center: CGPoint(x: c.x, y: horizon), radius: 0.2 * u, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            half.closeSubpath()
            ctx.fill(half, with: ink(bright))
            line(at(-0.38, 0.06), at(0.38, 0.06), mid, 1.2)
            for (i, alpha) in [mid, faint, faint * 0.6].enumerated() {
                let y = 0.14 + 0.08 * Double(i), half = 0.24 - 0.06 * Double(i)
                line(at(-half, y), at(half, y), alpha, 1.1)
            }
        case .stars:
            for i in 0..<7 {
                let p = at(SceneArt.rnd(i, 7) * 0.66 - 0.33, SceneArt.rnd(i, 11) * 0.66 - 0.33)
                if i == 0 {
                    let s = 0.09 * u
                    line(CGPoint(x: p.x - s, y: p.y), CGPoint(x: p.x + s, y: p.y), bright, 1.2)
                    line(CGPoint(x: p.x, y: p.y - s), CGPoint(x: p.x, y: p.y + s), bright, 1.2)
                } else {
                    dot(p, u * (0.016 + 0.014 * SceneArt.rnd(i, 1)), i % 2 == 0 ? mid : faint)
                }
            }
        case .fog:
            for (i, alpha) in [faint, mid, bright, mid, faint].enumerated() {
                let y = -0.24 + 0.12 * Double(i), half = 0.3 - 0.04 * abs(Double(i) - 2)
                line(at(-half, y), at(half, y), alpha, 1.6)
            }
        case .wind:
            for (i, alpha) in [bright, mid, faint].enumerated() {
                let y = -0.16 + 0.16 * Double(i)
                var p = Path()
                p.move(to: at(-0.34, y))
                p.addCurve(to: at(0.3, y - 0.02), control1: at(-0.1, y - 0.12), control2: at(0.08, y + 0.1))
                p.addArc(center: at(0.3, y - 0.07), radius: 0.05 * u, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
                ctx.stroke(p, with: ink(alpha), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }
        case .petals, .leaves:
            for i in 0..<6 {
                let p = at(SceneArt.rnd(i, 13) * 0.6 - 0.3, SceneArt.rnd(i, 17) * 0.6 - 0.3)
                var g = ctx
                g.translateBy(x: p.x, y: p.y)
                g.rotate(by: .degrees(SceneArt.rnd(i, 19) * 180))
                let w = u * (scene == .leaves ? 0.13 : 0.1), h = w * 0.55
                g.fill(Path(ellipseIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h)), with: ink(i % 2 == 0 ? bright : mid))
            }
        case .frost:
            for i in 0..<6 {
                let a = Double(i) * .pi / 3
                line(c, at(cos(a) * 0.3, sin(a) * 0.3), bright, 1.4)
                let b = at(cos(a) * 0.18, sin(a) * 0.18)
                for side in [-1.0, 1.0] {
                    let t = a + side * .pi / 4
                    line(b, CGPoint(x: b.x + cos(t) * 0.09 * u, y: b.y + sin(t) * 0.09 * u), mid, 1.1)
                }
            }
        }
    }

    /// 달 나이(0 삭 · 14.8 보름)대로 밝은 쪽 — 북반구에서 차오를 땐 오른쪽부터.
    static func moonLit(_ c: CGPoint, _ r: CGFloat, age: Double) -> Path {
        let phase = (age / Celestial.synodicMonth).truncatingRemainder(dividingBy: 1)
        let waxing = phase < 0.5
        let k = CGFloat(cos(2 * .pi * phase))
        var p = Path()
        let side: CGFloat = waxing ? 1 : -1
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        let steps = 24
        for i in 0...steps {
            let t = -CGFloat.pi / 2 + CGFloat.pi * CGFloat(i) / CGFloat(steps)
            p.addLine(to: CGPoint(x: c.x + side * r * cos(t), y: c.y + r * sin(t)))
        }
        for i in 0...steps {
            let t = CGFloat.pi / 2 - CGFloat.pi * CGFloat(i) / CGFloat(steps)
            p.addLine(to: CGPoint(x: c.x + side * k * r * cos(t), y: c.y + r * sin(t)))
        }
        p.closeSubpath()
        return p
    }
}
