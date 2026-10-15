import SwiftUI

/// 생일 말 카드 연출 — 웹 /birthday 의 카드 등장·굴림·내려앉기를 옮기고, 담으면 카드가 접혀 주운 말 첫 칸이 된다.
/// 모든 값은 「말 받기」부터 흐른 시간 t 하나로 정한다(프레임 확인 때 t 를 고정해 찍는다).
enum BirthdayReveal {

    // 웹 styles.css bd-* 와 같은 박자.
    static let rise = 0.7
    static let bloomAt = 0.15, bloomSpan = 1.4
    static let rollAt = 0.25, rollSpan = 1.7
    static let pop = 0.5
    static let reBloom = 0.9
    static let letterAt = 0.08, letterGap = 0.14, letterSpan = 0.75
    static let meaningAt = 0.6, meaningSpan = 0.7
    static let actionsAt = 1.1, actionsSpan = 0.6
    /// 내려앉으면 카드 위를 빛이 한 번 훑는다 — 첫 조약돌 증정과 같은 0.95초.
    static let sheenSpan = 0.95

    static let foldSpan = 0.85
    static let keptWordsAt = 0.55

    /// 굴림이 끝나 제 말에 멈추는 때 — 눌러서 일찍 멈추면 그때.
    static var land: Double { rollAt + rollSpan }

    /// 굴림 동안 말이 바뀌는 때(굴림 시작 기준) — 웹처럼 처음엔 빠르게, 갈수록 느리게(55 + k²·2.2ms).
    static let ticks: [Double] = {
        var out: [Double] = [], at = 0.0, k = 0.0
        while at < rollSpan {
            out.append(at)
            at += (55 + k * k * 2.2) / 1000
            k += 1
        }
        return out
    }()

    /// 굴리는 중이면 몇 번째로 스쳐 가는 말인지, 아니면 nil.
    static func tick(at t: Double, land: Double) -> Int? {
        guard t >= rollAt, t < land else { return nil }
        let r = t - rollAt
        return ticks.lastIndex { $0 <= r } ?? 0
    }

    /// 다 끝나는 때 — 이 뒤로는 시계를 멈춘다.
    static func settled(wordLength: Int, land: Double) -> Double {
        land + max(letterAt + Double(max(0, wordLength - 1)) * letterGap + letterSpan, actionsAt + actionsSpan, sheenSpan)
    }

    // cubic-bezier(0.2, 0.8, 0.2, 1) — 웹 카드·글자가 쓰는 곡선.
    static func curve(_ x: Double) -> Double {
        let u = SceneEase.clamp(x)
        guard u > 0, u < 1 else { return u }
        func bez(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
            3 * (1 - s) * (1 - s) * s * p1 + 3 * (1 - s) * s * s * p2 + s * s * s
        }
        var lo = 0.0, hi = 1.0
        for _ in 0..<22 {
            let mid = (lo + hi) / 2
            if bez(mid, 0.2, 0.2) < u { lo = mid } else { hi = mid }
        }
        return bez((lo + hi) / 2, 0.8, 1)
    }

    /// 담기 — 천천히 떠나 천천히 앉는다(작아지며 내려가는 게 보이게).
    static func fold(_ x: Double) -> Double {
        let u = SceneEase.clamp(x)
        return u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2
    }

    static func easeOut(_ x: Double) -> Double {
        let u = SceneEase.clamp(x)
        return 1 - (1 - u) * (1 - u)
    }

    static func seg(_ t: Double, _ at: Double, _ span: Double) -> Double { SceneEase.clamp((t - at) / span) }

    /// 철마다 다른 번짐 — 웹 카드 뒤 빛과 같은 색.
    static func glow(month: Int) -> Color {
        switch PhotoContext.season(month: month) {
        case .spring: Color(red: 244 / 255, green: 165 / 255, blue: 190 / 255)
        case .summer: Color(red: 120 / 255, green: 200 / 255, blue: 160 / 255)
        case .autumn: Color(red: 240 / 255, green: 170 / 255, blue: 90 / 255)
        case .winter: Color(red: 150 / 255, green: 180 / 255, blue: 240 / 255)
        }
    }
}

/// 생일 카드 배경 — 태어난 달의 철 하늘. 하늘이 있는 철(SkyScene.of)은 셰이더 하늘, 없으면 SceneView.
struct BirthdayCardSky: View {
    let month: Int
    var animating = true
    /// 큰 카드 hero, 접힌 주운 말 칸 card.
    var quality: SkyQuality = .hero

    static func kind(month: Int) -> SceneKind { .of(PhotoContext.season(month: month)) }

    var body: some View {
        SceneSky(kind: Self.kind(month: month), quality: quality, animating: animating)
    }
}

/// 장면 칸 전체 — 큰 카드(등장·굴림·내려앉기)와, 담은 뒤 접혀 내려간 주운 말 칸.
struct BirthdayRevealScene: View {
    let pick: BirthdayPick
    let month: Int
    let day: Int
    let passing: [String]
    /// 「말 받기」부터 흐른 시간.
    let t: Double
    let land: Double
    /// 「주운 말에 담기」부터 흐른 시간 — 담기 전엔 nil.
    let fold: Double?
    let still: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, area = geo.size.height
            let bigH = min(w * 1.25, area - 24)
            let rowH = WordSceneCard.rowHeight
            let e = foldProgress
            let h = bigH + (rowH - bigH) * e
            let bigTop = (area - bigH) / 2
            let rowTop = area * 0.6 - rowH / 2
            let top = bigTop + (rowTop - bigTop) * e

            ZStack(alignment: .topLeading) {
                glow(w: w, h: h)
                    .offset(y: top)
                card(w: w, bigH: bigH, h: h, e: e)
                    .scaleEffect(entryScale * popScale, anchor: .center)
                    .offset(y: top + entryY)
                    .opacity(entryOpacity)
                Text("주운 말")
                    .font(Face.caption).foregroundStyle(Tone.secondary)
                    .offset(x: 2, y: rowTop - 26)
                    .opacity(headerOpacity)
            }
            .frame(width: w, height: area, alignment: .topLeading)
        }
    }

    // MARK: 시간 → 모양

    private var rolling: Int? { still || fold != nil ? nil : BirthdayReveal.tick(at: t, land: land) }
    private var landed: Bool { still || t >= land }
    private var sinceLand: Double { t - land }

    private var entryOpacity: Double {
        still ? BirthdayReveal.easeOut(t / 0.6) : BirthdayReveal.easeOut(t / 0.5)
    }
    private var entryY: CGFloat { still ? 0 : 18 * (1 - BirthdayReveal.curve(t / BirthdayReveal.rise)) }
    private var entryScale: CGFloat { still ? 1 : 0.97 + 0.03 * BirthdayReveal.curve(t / BirthdayReveal.rise) }

    private var popScale: CGFloat {
        guard !still, landed, fold == nil else { return 1 }
        let p = BirthdayReveal.seg(t, land, BirthdayReveal.pop)
        guard p < 1 else { return 1 }
        let up = p < 0.4 ? BirthdayReveal.curve(p / 0.4) : 1 - BirthdayReveal.curve((p - 0.4) / 0.6)
        return 1 + 0.035 * up
    }

    private var foldProgress: Double {
        guard let fold else { return 0 }
        if still { return fold < 0.35 ? 0 : 1 }
        return BirthdayReveal.fold(fold / BirthdayReveal.foldSpan)
    }

    /// 큰 카드 장면이 칸 장면으로 넘어가는 정도 — 거의 다 접힌 뒤에 넘긴다.
    private var bigFade: Double {
        guard let fold else { return 0 }
        return still ? BirthdayReveal.easeOut(fold / 0.35) : SceneEase.inOut(BirthdayReveal.seg(fold, 0.4, 0.35))
    }

    /// 날짜·뜻이 먼저 빠진다.
    private var textFade: Double {
        guard let fold else { return 0 }
        return still ? BirthdayReveal.easeOut(fold / 0.35) : SceneEase.inOut(BirthdayReveal.seg(fold, 0, 0.3))
    }

    private var rowTextOpacity: Double {
        guard let fold else { return 0 }
        return still ? BirthdayReveal.easeOut((fold - 0.35) / 0.45) : BirthdayReveal.easeOut((fold - 0.55) / 0.35)
    }

    /// 「주운 말」 머리는 칸이 다 앉은 뒤에 — 일찍 뜨면 내려오는 카드와 겹친다.
    private var headerOpacity: Double {
        guard let fold else { return 0 }
        return still ? rowTextOpacity : BirthdayReveal.easeOut((fold - 0.8) / 0.4)
    }

    /// 카드 뒤 빛 — 번지고, 굴리는 동안 0.42초로 숨 쉬고, 내려앉으면 다시 번진다.
    private var glowLevel: (opacity: Double, scale: Double) {
        if still { return (0.55 * BirthdayReveal.easeOut(t / 0.8), 1) }
        if rolling != nil {
            let bloom = BirthdayReveal.easeOut(BirthdayReveal.seg(t, BirthdayReveal.bloomAt, 0.3))
            let b = 0.5 - 0.5 * cos((t - BirthdayReveal.rollAt) * .pi / 0.42)
            return (bloom * (0.35 + 0.35 * b), 0.85 + 0.23 * b)
        }
        if landed {
            let p = BirthdayReveal.easeOut(BirthdayReveal.seg(t, land, BirthdayReveal.reBloom))
            // 숨 쉬던 끝에서 한 번 크게 번졌다가 0.55 로 가라앉는다.
            let flare = sin(p * .pi) * 0.35
            return (0.45 + 0.1 * p + flare, 0.9 + 0.1 * p + flare * 0.25)
        }
        let p = BirthdayReveal.easeOut(BirthdayReveal.seg(t, BirthdayReveal.bloomAt, BirthdayReveal.bloomSpan))
        return (0.55 * p, 0.6 + 0.4 * p)
    }

    private func glow(w: CGFloat, h: CGFloat) -> some View {
        let g = glowLevel
        return Ellipse()
            .fill(BirthdayReveal.glow(month: month))
            .frame(width: w * 1.1, height: h * 0.95)
            .blur(radius: 50)
            .scaleEffect(g.scale)
            .opacity(min(1, g.opacity * 1.25) * (1 - bigFade * 0.6))
            .frame(width: w, height: h)
            .allowsHitTesting(false)
    }

    // MARK: 카드

    private func card(w: CGFloat, bigH: CGFloat, h: CGFloat, e: Double) -> some View {
        ZStack(alignment: .topLeading) {
            // 접히는 동안 장면을 늘려 그리지 않는다 — 큰 그림을 위에 붙여 자르고, 칸 크기 그림으로 넘긴다.
            BirthdayCardSky(month: month, animating: !still)
                .frame(width: w, height: bigH)
                .opacity(1 - bigFade)
            // 웹 카드처럼 가운데 위쪽에 철 빛이 비친다.
            RadialGradient(colors: [BirthdayReveal.glow(month: month).opacity(0.26), .clear],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: w * 0.75)
                .frame(width: w, height: bigH)
                .opacity(glowLevel.opacity / 0.55 * (1 - bigFade))
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            if fold != nil {
                BirthdayCardSky(month: month, animating: !still, quality: .card)
                    .frame(width: w, height: WordSceneCard.rowHeight)
                    .offset(y: (h - WordSceneCard.rowHeight) / 2)
                    .opacity(bigFade)
            }
            sheen(w: w, h: h)
            bigWords(w: w, bigH: bigH, h: h, e: e)
            rowWords(w: w, h: h)
                .opacity(rowTextOpacity)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 26 + (22 - 26) * e, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26 + (22 - 26) * e, style: .continuous)
            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        .shadow(color: Tone.pure.opacity(0.45), radius: 22, y: 12)
    }

    private func sheen(w: CGFloat, h: CGFloat) -> some View {
        let p = landed && !still && fold == nil ? SceneEase.inOut(BirthdayReveal.seg(t, land, BirthdayReveal.sheenSpan)) : 0
        let on = p > 0 && p < 1
        return LinearGradient(colors: [.white.opacity(0), .white.opacity(0.13), .white.opacity(0)],
                              startPoint: .leading, endPoint: .trailing)
            .frame(width: w * 0.55, height: h * 1.6)
            .rotationEffect(.degrees(18))
            .offset(x: -w * 0.6 + (w * 1.7) * p, y: -h * 0.3)
            .opacity(on ? 1 : 0)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    private var dateText: String {
        rolling != nil || (!landed && !still) ? "\(month)월 \(day)일의 말은…" : "\(month)월 \(day)일의 말"
    }

    private func wordSize(_ blockW: CGFloat, max size: CGFloat) -> CGFloat {
        min(size, (blockW / CGFloat(max(1, pick.word.count))).rounded(.down))
    }

    // 큰 카드 — 위 라벨, 아래 말·뜻(SceneArt.textRects 의 세로 카드 자리, 장면 그림은 오른쪽 위로 비킨다).
    private func bigWords(w: CGFloat, bigH: CGFloat, h: CGFloat, e: Double) -> some View {
        let pad: CGFloat = 20
        let blockW = 0.78 * w - pad - 4
        let big = wordSize(blockW, max: 48)
        let small = wordSize(0.44 * w - 18, max: 28)
        let size = big + (small - big) * e
        let wordTop = (0.5 * bigH + 6) + (12 - (0.5 * bigH + 6)) * e
        let x = pad + (18 - pad) * e
        let fade = 1 - textFade
        let meaningTop = wordTop + big * 1.3 + 4 + CGFloat(14 * (1 - rise(BirthdayReveal.meaningAt, BirthdayReveal.meaningSpan)))
        let tone = BirthdayCardSky.kind(month: month).smallTextTone
        return ZStack(alignment: .topLeading) {
            Text(dateText)
                .font(Face.caption).foregroundStyle(tone)
                .padding(.leading, pad).padding(.top, 18)
                .opacity(dateOpacity * fade)
            word(size: size)
                .frame(width: max(blockW, 0.44 * w - 18), alignment: .leading)
                .offset(x: x, y: wordTop)
            Text(pick.meaning)
                .font(Face.line).foregroundStyle(tone)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: blockW, alignment: .leading)
                .offset(x: pad, y: meaningTop)
                .opacity(meaningOpacity * fade)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .skyText()
    }

    private var dateOpacity: Double {
        if still { return BirthdayReveal.easeOut(t / 0.6) }
        if landed { return BirthdayReveal.easeOut(BirthdayReveal.seg(t, land, 0.4)) }
        return BirthdayReveal.easeOut(BirthdayReveal.seg(t, 0.2, 0.6))
    }

    /// 내려앉은 뒤 at 부터 span 동안 0→1(웹 bd-rise 곡선).
    private func rise(_ at: Double, _ span: Double) -> Double {
        if still { return 1 }
        guard landed else { return 0 }
        return BirthdayReveal.curve(BirthdayReveal.seg(sinceLand, at, span))
    }

    private var meaningOpacity: Double {
        if still { return BirthdayReveal.easeOut((t - 0.5) / 0.6) }
        guard landed else { return 0 }
        return BirthdayReveal.curve(BirthdayReveal.seg(sinceLand, BirthdayReveal.meaningAt, BirthdayReveal.meaningSpan))
    }

    @ViewBuilder
    private func word(size: CGFloat) -> some View {
        let face = Font.custom(Face.serifName, size: size)
        if let i = rolling, !passing.isEmpty {
            // 스쳐 가는 말 — 흐릿하고 반투명, 느려질수록 조금씩 또렷해진다.
            let slow = Double(i) / Double(max(1, BirthdayReveal.ticks.count - 1))
            Text(passing[i % passing.count])
                .font(face).foregroundStyle(Tone.primary)
                .lineLimit(1).minimumScaleFactor(0.5)
                .opacity(0.4 + 0.18 * slow)
                .blur(radius: 3.5 - 2 * slow)
        } else if !landed {
            Color.clear.frame(height: size * 1.2)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(pick.word.enumerated()), id: \.offset) { i, ch in
                    let p = letter(i)
                    Text(String(ch))
                        .font(face).foregroundStyle(Tone.primary)
                        .opacity(p)
                        .offset(y: 12 * (1 - p))
                        .blur(radius: 10 * (1 - p))
                }
            }
            .opacity(still ? BirthdayReveal.easeOut((t - 0.2) / 0.6) : 1)
            .fixedSize()
        }
    }

    private func letter(_ i: Int) -> Double {
        guard !still, fold == nil else { return 1 }
        let at = BirthdayReveal.letterAt + Double(i) * BirthdayReveal.letterGap
        return BirthdayReveal.curve(BirthdayReveal.seg(sinceLand, at, BirthdayReveal.letterSpan))
    }

    // 주운 말 칸 — WordSceneCard.row 와 같은 자리(말은 큰 카드에서 줄어들며 넘어온다).
    private func rowWords(w: CGFloat, h: CGFloat) -> some View {
        let small = BirthdayCardSky.kind(month: month).smallTextTone
        return ZStack(alignment: .topLeading) {
            Text("방금").font(Face.caption).foregroundStyle(small)
                .frame(width: 0.36 * w - 18, height: 0.32 * h, alignment: .bottomLeading)
                .padding(.leading, 18)
                .offset(y: 0.6 * h)
            Text("생일").font(Face.caption).foregroundStyle(small)
                .frame(width: 0.22 * w - 16, height: 0.42 * h - 12, alignment: .topTrailing)
                .padding(.top, 12)
                .offset(x: 0.78 * w)
            Text(BirthdayCardSky.kind(month: month).name).font(Face.caption).foregroundStyle(small)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: 0.22 * w - 16, height: 0.32 * h, alignment: .bottomTrailing)
                .offset(x: 0.78 * w, y: 0.6 * h)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .skyText()
    }
}

/// 장면 아래 글·버튼이 따라 오르는 정도 — 웹 bd-actions(내려앉은 뒤 1.1초).
enum BirthdayRevealFollow {
    static func shown(t: Double, land: Double, still: Bool) -> Double {
        if still { return BirthdayReveal.easeOut((t - 0.9) / 0.6) }
        return BirthdayReveal.curve(BirthdayReveal.seg(t - land, BirthdayReveal.actionsAt, BirthdayReveal.actionsSpan))
    }

    static func kept(fold: Double, still: Bool) -> Double {
        if still { return BirthdayReveal.easeOut((fold - 0.5) / 0.5) }
        return BirthdayReveal.curve(BirthdayReveal.seg(fold, BirthdayReveal.keptWordsAt, 0.6))
    }
}
