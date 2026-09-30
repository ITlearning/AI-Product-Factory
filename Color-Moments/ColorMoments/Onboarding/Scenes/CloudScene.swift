import SwiftUI

/// iCloud — 켜져 있으면 두 기기 위 구름까지 점선이 이어지고 점이 흐른다. 조약돌은 점선을 타고
/// 왼쪽 기기에서 구름으로 들어갔다가 오른쪽 기기로 내려온다. 꺼져 있으면 한 대 안에 머문다.
/// 받아 오는 중이면 구름에서 오른쪽 기기로만 흐르고, 조약돌이 차례로 떨어지며 개수를 센다.
struct CloudScene: View {
    let linked: Bool
    let receiving: Bool
    let remoteDays: Int

    private static let gap: CGFloat = 72
    private static let phoneTop: CGFloat = -(92 * 2.05) / 2
    private static let cloudY: CGFloat = -150
    private static let canvas = CGSize(width: 320, height: 380)

    /// 기기 윗변에서 곧게 올라가다 구름 쪽으로 꺾이는 선 — 조약돌도 이 선을 탄다.
    private struct Wire {
        let a: CGPoint, c: CGPoint, b: CGPoint

        func point(_ u: Double) -> CGPoint {
            let v = 1 - u
            return CGPoint(x: v * v * a.x + 2 * v * u * c.x + u * u * b.x,
                           y: v * v * a.y + 2 * v * u * c.y + u * u * b.y)
        }
    }

    private static let up = Wire(a: CGPoint(x: -gap, y: phoneTop - 12), c: CGPoint(x: -gap, y: cloudY + 6),
                                 b: CGPoint(x: -28, y: cloudY + 6))
    private static let down = Wire(a: CGPoint(x: 28, y: cloudY + 6), c: CGPoint(x: gap, y: cloudY + 6),
                                   b: CGPoint(x: gap, y: phoneTop - 12))

    var body: some View {
        SceneClock { t, moving in
            ZStack {
                if linked {
                    wires(t: t, moving: moving)
                    Image(systemName: "icloud")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(Tone.primary.opacity(0.85))
                        .offset(y: Self.cloudY)
                    PhoneSilhouette { pile(t: t, moving: moving) }
                        .offset(x: Self.gap)
                    PhoneSilhouette { Color.clear }
                        .offset(x: -Self.gap)
                    if !receiving { courier(t: t, moving: moving) }
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

    /// 점선 두 가닥 — 왼쪽은 기기에서 구름으로, 오른쪽은 구름에서 기기로 점이 흐른다(받아 오는 중엔 오른쪽만).
    private func wires(t: Double, moving: Bool) -> some View {
        Canvas { ctx, size in
            let o = CGPoint(x: size.width / 2, y: size.height / 2)
            func shifted(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + o.x, y: p.y + o.y) }
            for (wire, flows) in [(Self.up, !receiving), (Self.down, true)] {
                var path = Path()
                path.move(to: shifted(wire.a))
                path.addQuadCurve(to: shifted(wire.b), control: shifted(wire.c))
                // dashPhase 가 줄어들면 점이 선의 진행 방향(a → b)으로 흐른다.
                let phase = moving && flows ? -t * 18 : 0
                ctx.stroke(path, with: .color(Tone.secondary.opacity(flows ? 0.8 : 0.35)),
                           style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [0.1, 8], dashPhase: phase))
            }
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height)
        .allowsHitTesting(false)
    }

    /// 조약돌 하나가 왼쪽 선을 타고 구름에 들어갔다가, 잠깐 뒤 오른쪽 선으로 내려온다.
    private func courier(t: Double, moving: Bool) -> some View {
        let period = 4.4
        let p = moving ? t.truncatingRemainder(dividingBy: period) / period : 0.25
        let rising = p < 0.44
        let u = rising ? SceneEase.inOut(p / 0.44) : SceneEase.inOut(SceneEase.segment(p, from: 0.56, to: 1))
        let at = rising ? Self.up.point(u) : Self.down.point(u)
        // 구름 가까이에선 스며들듯 사라졌다 나타난다.
        let fade = rising ? SceneEase.clamp((1 - u) / 0.18) : (p < 0.56 ? 0 : SceneEase.clamp(u / 0.18))
        return MiniPebble(height: 18)
            .offset(x: at.x, y: at.y)
            .opacity(fade)
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
