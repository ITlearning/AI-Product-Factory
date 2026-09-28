import SwiftUI

/// 소개 — 조약돌이 굴러와 멈추면 그 뒤로 색이 번진다.
struct IntroScene: View {
    let moments: [Moment]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @State private var bloomed = false

    var body: some View {
        ZStack {
            SceneClock { t, _ in
                ZStack {
                    ForEach(Array(moments.prefix(3).enumerated()), id: \.offset) { i, m in
                        Bloom(hex: m.colorHex, index: i, t: t, bloomed: bloomed)
                    }
                }
            }
            .blendMode(.plusLighter)
            PebbleView(moments: moments, height: 150)
                .offset(x: arrived || reduceMotion ? 0 : -260)
                .rotationEffect(.degrees(arrived || reduceMotion ? 0 : -150))
                .opacity(arrived ? 1 : 0)
        }
        .onAppear {
            let roll: Animation = reduceMotion ? .easeOut(duration: 0.6) : .easeOut(duration: 1.6)
            withAnimation(roll.delay(0.25)) { arrived = true }
            let bloom: Animation = reduceMotion ? .easeOut(duration: 0.6) : .easeOut(duration: 2.4)
            withAnimation(bloom.delay(reduceMotion ? 0.25 : 1.5)) { bloomed = true }
        }
    }
}

private struct Bloom: View {
    let hex: String
    let index: Int
    let t: Double
    let bloomed: Bool

    var body: some View {
        let i = Double(index)
        let drift = sin(t * 2 * .pi / (9 + i * 2.5) + i)
        let gradient = RadialGradient(colors: [Color(hex: hex).opacity(0.55), .clear],
                                      center: .center, startRadius: 0, endRadius: 120)
        Circle()
            .fill(gradient)
            .frame(width: 240, height: 240)
            .scaleEffect(bloomed ? 1.15 + 0.06 * drift : 0.3)
            .offset(x: (i - 1) * 46 + 8 * drift, y: Double(index % 2) * 24 - 12)
            .opacity(bloomed ? 1 : 0)
    }
}
