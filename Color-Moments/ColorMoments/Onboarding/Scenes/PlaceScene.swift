import SwiftUI

/// 온보딩 「찍은 곳」 — 허용하면 사진 보기에 이렇게 붙는다: 동네가 뜨고, 날씨가 뜨고, 누르면 지도가 펼쳐진다.
struct PlaceScene: View {

    static let cycle = 7.5

    var body: some View {
        SceneClock { t, moving in
            let p = t.truncatingRemainder(dividingBy: Self.cycle)
            let s = PlaceMotion.state(at: p, moving: moving)
            VStack(alignment: .leading, spacing: 0) {
                RiverPhoto(t: t)
                    .frame(height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text("윤슬").font(Face.nameHome).foregroundStyle(Tone.primary)
                    .padding(.top, 12)
                Text("햇빛이나 달빛에 비쳐 반짝이는 잔물결").font(Face.caption).foregroundStyle(Tone.tertiary)
                    .padding(.top, 2)
                HStack(spacing: 0) {
                    HStack(spacing: 5) {
                        Circle().fill(Color(hex: "#C98F7A")).frame(width: 7, height: 7)
                        Text("저녁(18:40)").monospacedDigit()
                    }
                    .fixedSize()
                    Piece(icon: "mappin", text: "망원동", progress: s.place)
                    Piece(icon: "sun.max", text: "맑음 21°", progress: s.weather)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(-180 * s.map))
                        .padding(.leading, 9)
                }
                .font(Face.caption)
                .foregroundStyle(Tone.secondary)
                .padding(.top, 10)
                MiniMap()
                    .frame(height: 64 * s.map)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .opacity(s.map)
                    .padding(.top, 8 * s.map)
            }
            .frame(width: 264)
        }
        .accessibilityHidden(true)
    }
}

enum PlaceMotion {
    struct State: Equatable {
        var place: Double
        var weather: Double
        var map: Double
    }

    /// 한 주기(7.5초) — 동네 0.8~1.5초 · 날씨 1.9~2.6초 · 지도 펼침 3.4~4.0초, 접힘 5.8~6.3초 · 걷힘 6.6~7.1초.
    static func state(at p: Double, moving: Bool) -> State {
        guard moving else { return State(place: 1, weather: 1, map: 1) }
        let fade = 1 - SceneEase.inOut(SceneEase.segment(p, from: 6.6, to: 7.1))
        let place = SceneEase.inOut(SceneEase.segment(p, from: 0.8, to: 1.5)) * fade
        let weather = SceneEase.inOut(SceneEase.segment(p, from: 1.9, to: 2.6)) * fade
        let open = SceneEase.inOut(SceneEase.segment(p, from: 3.4, to: 4.0))
        let close = SceneEase.inOut(SceneEase.segment(p, from: 5.8, to: 6.3))
        return State(place: place, weather: weather, map: open * (1 - close))
    }
}

/// 동네·날씨 한 조각 — 앱처럼 자리가 벌어지며(V가 따라 미끄러진다) 글자가 흐릿하게 올라온다.
private struct Piece: View {
    let icon: String
    let text: String
    let progress: Double

    var body: some View {
        Grow(progress: progress) {
            HStack(spacing: 3) {
                Image(systemName: icon).imageScale(.small)
                Text(text).monospacedDigit()
            }
            .fixedSize()
            .padding(.leading, 9)
            .opacity(progress)
            .blur(radius: (1 - progress) * 3)
            .offset(y: (1 - progress) * 5)
        }
    }
}

/// 제 크기대로 그리되 폭은 progress 만큼만 차지한다.
private struct Grow: Layout {
    var progress: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let size = subviews.first?.sizeThatFits(.unspecified) else { return .zero }
        return CGSize(width: size.width * progress, height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: .unspecified)
    }
}

/// 노을 지는 강 — 잔물결이 반짝인다.
private struct RiverPhoto: View {
    let t: Double

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#F4C3A6"), Color(hex: "#C99AB0"), Color(hex: "#6E7FAE"), Color(hex: "#2F3B63")],
                           startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                for i in 0..<9 {
                    let x = size.width * (0.12 + 0.09 * Double(i)) + 14 * sin(Double(i) * 1.7)
                    let y = size.height * (0.6 + 0.04 * Double(i % 4))
                    let twinkle = 0.25 + 0.35 * (0.5 + 0.5 * sin(t * 2.2 + Double(i) * 1.3))
                    context.opacity = twinkle
                    context.fill(Path(roundedRect: CGRect(x: x, y: y, width: 16 + Double(i % 3) * 6, height: 2),
                                      cornerRadius: 1), with: .color(.white))
                }
            }
        }
    }
}

/// 사진 보기에서 펼쳐지는 어두운 지도 — 길 몇 줄과 점 하나.
private struct MiniMap: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#1C1D21")))
            var river = Path()
            river.move(to: CGPoint(x: -4, y: size.height * 0.75))
            river.addCurve(to: CGPoint(x: size.width + 4, y: size.height * 0.55),
                           control1: CGPoint(x: size.width * 0.35, y: size.height * 0.95),
                           control2: CGPoint(x: size.width * 0.65, y: size.height * 0.4))
            context.stroke(river, with: .color(Color(hex: "#1B2A3C")), lineWidth: 9)
            for (a, b) in [(CGPoint(x: 0.1, y: 0), CGPoint(x: 0.3, y: 1)), (CGPoint(x: 0.45, y: 0), CGPoint(x: 0.58, y: 1)),
                           (CGPoint(x: 0, y: 0.3), CGPoint(x: 1, y: 0.22)), (CGPoint(x: 0.75, y: 0), CGPoint(x: 0.9, y: 1))] {
                var road = Path()
                road.move(to: CGPoint(x: a.x * size.width, y: a.y * size.height))
                road.addLine(to: CGPoint(x: b.x * size.width, y: b.y * size.height))
                context.stroke(road, with: .color(Color(hex: "#2F3238")), lineWidth: 2)
            }
            let dot = CGPoint(x: size.width * 0.52, y: size.height * 0.45)
            context.fill(Path(ellipseIn: CGRect(x: dot.x - 11, y: dot.y - 11, width: 22, height: 22)),
                         with: .color(.white.opacity(0.14)))
            context.fill(Path(ellipseIn: CGRect(x: dot.x - 4.5, y: dot.y - 4.5, width: 9, height: 9)),
                         with: .color(Color(hex: "#C98F7A")))
            context.stroke(Path(ellipseIn: CGRect(x: dot.x - 4.5, y: dot.y - 4.5, width: 9, height: 9)),
                           with: .color(.white.opacity(0.88)), lineWidth: 1.4)
        }
    }
}
