import SwiftUI

/// 소개 — 조약돌이 위에서 살며시 내려와 자리에 앉으면 그 뒤로 색이 번진다.
/// 굴려서 들이지 않는다 — 둥근 돌은 빛·그늘이 그려진 돌이라 돌리면 빛까지 같이 돈다.
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
            // 뒤에 번지는 색이 이미 후광 노릇을 한다 — 둥근 돌 후광까지 겹치면 너무 밝다.
            PebbleView(moments: moments, height: 150, glow: .bare)
                .offset(y: arrived || reduceMotion ? 0 : -70)
                .scaleEffect(arrived || reduceMotion ? 1 : 0.9)
                .opacity(arrived ? 1 : 0)
        }
        .onAppear {
            // 살짝 튕기며 앉는다 — 크게 출렁이지 않게 감쇠를 넉넉히.
            let land: Animation = reduceMotion ? .easeOut(duration: 0.6) : .spring(response: 1.0, dampingFraction: 0.72)
            withAnimation(land.delay(0.25)) { arrived = true }
            let bloom: Animation = reduceMotion ? .easeOut(duration: 0.6) : .easeOut(duration: 2.4)
            withAnimation(bloom.delay(reduceMotion ? 0.25 : 0.9)) { bloomed = true }
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
