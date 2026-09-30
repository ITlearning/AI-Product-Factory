import SwiftUI

/// 아침 소식 — 잠금화면 알림 카드가 위에서 내려와 살짝 흔들리고 멈춘다. 뒤로 새벽이 아침이 된다.
struct ArrivalScene: View {

    static let cycle = 7.0

    var body: some View {
        SceneClock { t, moving in
            let state = NoticeMotion.state(at: t.truncatingRemainder(dividingBy: Self.cycle), moving: moving)
            ZStack {
                Sky(mix: moving ? (1 - cos(t * 2 * .pi / 24)) / 2 : 0.6)
                // 카드 양옆은 아래 글·버튼 줄과 같은 선에(Tabber).
                NoticeCard()
                    .rotationEffect(.degrees(state.angle), anchor: .top)
                    .offset(y: state.y)
                    .opacity(state.opacity)
            }
        }
        .accessibilityHidden(true)
    }
}

enum NoticeMotion {
    struct State: Equatable {
        var y: Double
        var angle: Double
        var opacity: Double
    }

    /// 한 주기(7초) — 내려오기 0.9초 · 흔들림 0.7초 · 머묾 · 걷힘 0.6초 · 빈 틈.
    static func state(at p: Double, moving: Bool) -> State {
        guard moving else { return State(y: 0, angle: 0, opacity: 1) }
        let drop = SceneEase.segment(p, from: 0, to: 0.9)
        let wiggle = SceneEase.segment(p, from: 0.9, to: 1.6)
        let leave = SceneEase.segment(p, from: 5.2, to: 5.8)
        let y = -120 * (1 - SceneEase.outBack(drop)) - 14 * SceneEase.inOut(leave)
        let angle = wiggle > 0 && wiggle < 1 ? 2.2 * sin(wiggle * 6 * .pi) * (1 - wiggle) : 0
        let opacity = min(SceneEase.clamp(drop * 2.5), 1 - SceneEase.inOut(leave))
        return State(y: y, angle: angle, opacity: opacity)
    }
}

private struct Sky: View {
    let mix: Double

    private static func rgb(_ hex: String) -> ColorExtractor.RGB {
        PebbleNaming.rgb(fromHex: hex) ?? .init(r: 0, g: 0, b: 0)
    }

    private static func blend(_ a: String, _ b: String, _ k: Double) -> Color {
        let x = rgb(a), y = rgb(b)
        return Color(red: x.r + (y.r - x.r) * k, green: x.g + (y.g - x.g) * k, blue: x.b + (y.b - x.b) * k)
    }

    var body: some View {
        let top = Self.blend(Tone.skyDawn[0], Tone.skyMorning[0], mix)
        let bottom = Self.blend(Tone.skyDawn[1], Tone.skyMorning[1], mix)
        // 빛은 장면 폭 안에서 다 사그라든다 — 반지름이 폭의 절반보다 크면 양옆에 세로 경계가 보였다.
        GeometryReader { geo in
            LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
                .mask(RadialGradient(colors: [.black, .black.opacity(0)], center: .center,
                                     startRadius: 40, endRadius: min(geo.size.width, geo.size.height) / 2))
        }
        .opacity(0.9)
    }
}

/// 잠금화면 알림 모양 — 앱 아이콘 자리에 색을 숨긴 회색 조약돌.
struct NoticeCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Tone.base)
                .frame(width: 38, height: 38)
                .overlay { MiniPebble(height: 20, fill: Tone.tertiary) }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("몽돌").font(Face.noticeApp).foregroundStyle(Tone.primary)
                    Spacer()
                    Text("지금").font(Face.caption).foregroundStyle(Tone.tertiary)
                }
                Text(ArrivalNotice.body).font(Face.line).foregroundStyle(Tone.primary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Tone.hairline, lineWidth: 0.5))
        .environment(\.colorScheme, .dark)
    }
}
