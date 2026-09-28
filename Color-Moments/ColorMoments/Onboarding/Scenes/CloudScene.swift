import SwiftUI

/// iCloud — 켜져 있으면 두 기기 사이로 조약돌이 오가고, 꺼져 있으면 한 대 안에 머문다.
/// 받아 오는 중이면 조약돌이 차례로 떨어지며 개수를 센다.
struct CloudScene: View {
    let linked: Bool
    let receiving: Bool
    let remoteDays: Int

    private static let gap: CGFloat = 72
    private static let pileMax = 5

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

    /// 받아 오는 동안 한 알씩 떨어져 쌓인다 — 다 차면 비우고 다시.
    private func pile(t: Double, moving: Bool) -> some View {
        let step = 0.55
        let shown = receiving && moving ? Int(t / step) % (Self.pileMax + 2) : min(remoteDays, Self.pileMax)
        let fall = receiving && moving ? SceneEase.inOut((t / step).truncatingRemainder(dividingBy: 1)) : 1
        return ZStack(alignment: .bottom) {
            Color.clear
            VStack(spacing: 2) {
                ForEach(0..<min(shown, Self.pileMax), id: \.self) { i in
                    let newest = i == 0 && receiving && moving
                    MiniPebble(height: 16)
                        .offset(y: newest ? -120 * (1 - fall) : 0)
                        .opacity(newest ? fall : 1)
                }
            }
            .padding(.bottom, 16)
        }
    }
}
