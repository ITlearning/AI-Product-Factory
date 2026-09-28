import SwiftUI

/// iCloud — 켜져 있으면 두 기기 사이로 조약돌이 오가고, 꺼져 있으면 한 대 안에 머문다.
/// 받아 오는 중이면 조약돌이 차례로 떨어지며 개수를 센다.
struct CloudScene: View {
    let linked: Bool
    let receiving: Bool
    let remoteDays: Int

    private static let gap: CGFloat = 72

    var body: some View {
        SceneClock { t, moving in
            ZStack {
                if linked {
                    PhoneSilhouette { pile(t: t, moving: moving) }
                        .offset(x: Self.gap)
                    PhoneSilhouette { Color.clear }
                        .offset(x: -Self.gap)
                    if !receiving { shuttle(t: t, moving: moving) }
                } else {
                    PhoneSilhouette {
                        MiniPebble(height: 24)
                            .offset(y: moving ? 4 * sin(t * 2 * .pi / 3.6) : 0)
                    }
                }
                if remoteDays > 0 {
                    Text("\(remoteDays)")
                        .font(Face.caption)
                        .foregroundStyle(Tone.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .offset(x: Self.gap, y: 118)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: linked)
        }
        .accessibilityHidden(true)
    }

    /// 왼쪽에서 오른쪽으로 호를 그리며 건너가고 돌아온다.
    private func shuttle(t: Double, moving: Bool) -> some View {
        let period = 4.0
        let p = moving ? t.truncatingRemainder(dividingBy: period) / period : 0.5
        let leg = p < 0.5 ? p * 2 : (1 - p) * 2
        let u = SceneEase.inOut(SceneEase.segment(leg, from: 0.15, to: 0.85))
        return MiniPebble(height: 20)
            .offset(x: -Self.gap + 2 * Self.gap * u, y: -46 * sin(.pi * u))
    }

    /// 받아 오는 동안 한 알씩 떨어져 먼저 온 돌 위에 살짝 겹쳐 쌓인다 — 다 차면 맨 위만 바뀐다.
    private func pile(t: Double, moving: Bool) -> some View {
        let step = 0.55
        let live = receiving && moving
        let arrived = live ? Int(t / step) + 1 : remoteDays
        let visible = min(arrived, CloudPile.maxVisible)
        let fall = live ? SceneEase.inOut((t / step).truncatingRemainder(dividingBy: 1)) : 1
        let replacing = live && arrived > CloudPile.maxVisible
        return ZStack(alignment: .bottom) {
            Color.clear
            ZStack(alignment: .bottom) {
                ForEach(0..<visible, id: \.self) { i in
                    let top = live && i == visible - 1
                    if top && replacing { stone(i).opacity(1 - fall) }
                    stone(i)
                        .offset(y: top ? -120 * (1 - fall) : 0)
                        .opacity(top ? fall : 1)
                }
            }
            .padding(.bottom, 22)
        }
    }

    private func stone(_ i: Int) -> some View {
        let slot = CloudPile.slot(i)
        return MiniPebble(height: 16)
            .overlay { PebbleShape(top: 0.44, bottom: 0.40).stroke(Tone.base, lineWidth: 1) }
            .rotationEffect(.degrees(slot.angle))
            .offset(x: slot.x, y: -slot.rise)
    }
}

/// 오른쪽 폰에 쌓이는 조약돌 자리 — 한 알씩 조금 더 위, 좌우로 엇갈리고 살짝 기운다(늘 같은 자리).
enum CloudPile {
    static let maxVisible = 7
    static let rise: CGFloat = 7
    private static let xs: [CGFloat] = [0, 4, -3, 5, -5, 2, -2]
    private static let angles: [Double] = [-3, 5, -6, 4, -2, 6, -4]

    static func slot(_ i: Int) -> (x: CGFloat, rise: CGFloat, angle: Double) {
        let k = i % xs.count
        return (xs[k], CGFloat(i) * rise, angles[k])
    }
}
