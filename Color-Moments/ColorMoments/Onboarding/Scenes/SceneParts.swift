import SwiftUI

/// 장면(위) · 글(아래) — 위 장면이 남는 높이를 채워 빈 검은 공간이 생기지 않게 한다.
struct SceneLayout<Scene: View, Words: View>: View {
    @ViewBuilder let scene: Scene
    @ViewBuilder let words: Words

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            scene
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            words
            Spacer().frame(height: 28)
        }
    }
}

/// 장면 안 휴대폰 윤곽.
struct PhoneSilhouette<Screen: View>: View {
    var width: CGFloat = 92
    @ViewBuilder let screen: Screen

    private var height: CGFloat { width * 2.05 }
    private var radius: CGFloat { width * 0.2 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Tone.pure.opacity(0.35))
            screen
                .clipShape(RoundedRectangle(cornerRadius: radius - 5, style: .continuous))
                .padding(5)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Tone.hairline, lineWidth: 1.5)
            Capsule()
                .fill(Tone.hairline)
                .frame(width: width * 0.28, height: 5)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 11)
        }
        .frame(width: width, height: height)
    }
}

/// 색을 숨긴 작은 조약돌 — 도착 소식·iCloud 장면에서 쓴다.
struct MiniPebble: View {
    var height: CGFloat = 22
    var fill: Color = Tone.secondary

    var body: some View {
        PebbleShape(top: 0.44, bottom: 0.40)
            .fill(fill)
            .frame(width: height * Shape2.pebbleRatio, height: height)
    }
}

/// 가운데서 천천히 숨 쉬듯 — 크기 0.98↔1.02, 위아래 3pt.
struct Breathing: ViewModifier {
    var period = 4.8

    func body(content: Content) -> some View {
        SceneClock { t, _ in
            let phase = sin(t * 2 * .pi / period)
            content
                .scaleEffect(1 + 0.02 * phase)
                .offset(y: -3 * phase)
        }
    }
}

extension View {
    func breathing(period: Double = 4.8) -> some View { modifier(Breathing(period: period)) }
}

/// 장면 모션 계산용 — 0…1 로 자르고 부드럽게.
enum SceneEase {
    static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }

    static func inOut(_ x: Double) -> Double {
        let u = clamp(x)
        return u * u * (3 - 2 * u)
    }

    /// 살짝 넘쳤다 돌아오는 도착.
    static func outBack(_ x: Double) -> Double {
        let u = clamp(x), c = 1.4
        return 1 + (c + 1) * pow(u - 1, 3) + c * pow(u - 1, 2)
    }

    static func segment(_ t: Double, from a: Double, to b: Double) -> Double { clamp((t - a) / (b - a)) }
}
