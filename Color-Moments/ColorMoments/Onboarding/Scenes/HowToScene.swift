import SwiftUI

/// 찍는 법 — 휴대폰 안에서 손가락이 왼쪽 가장자리를 오른쪽으로 쓸면 카메라 면이 밀려 나온다.
struct HowToScene: View {

    fileprivate static let width: CGFloat = 108

    var body: some View {
        SceneClock { t, moving in
            let s = SwipeMotion.state(at: t.truncatingRemainder(dividingBy: SwipeMotion.cycle), moving: moving)
            PhoneSilhouette(width: Self.width) {
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        MiniHome()
                        camera
                            .offset(x: -w + w * s.progress)
                        SwipeFinger()
                            .offset(x: 2 + (w - 34) * s.progress, y: 0)
                            .opacity(s.finger)
                            .frame(maxHeight: .infinity)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var camera: some View {
        ZStack {
            Rectangle().fill(Tone.pure)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Tone.hairline, lineWidth: 1)
                .padding(.horizontal, 10)
                .padding(.top, 30)
                .padding(.bottom, 58)
            Circle()
                .strokeBorder(Tone.primary, lineWidth: 2)
                .frame(width: 30, height: 30)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 16)
        }
    }
}

/// 모은 조약돌 — 찍는 법의 거울. 손가락이 오른쪽 가장자리를 왼쪽으로 쓸면 조약돌 3열 면이 오른쪽에서 밀려 들어온다.
struct CollectionScene: View {

    var body: some View {
        SceneClock { t, moving in
            let s = SwipeMotion.state(at: t.truncatingRemainder(dividingBy: SwipeMotion.cycle), moving: moving)
            PhoneSilhouette(width: HowToScene.width) {
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .trailing) {
                        MiniHome()
                        collection
                            .offset(x: w - w * s.progress)
                        SwipeFinger()
                            .offset(x: -2 - (w - 34) * s.progress, y: 0)
                            .opacity(s.finger)
                            .frame(maxHeight: .infinity)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var collection: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Tone.pure)
            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<2, id: \.self) { month in
                    VStack(alignment: .leading, spacing: 10) {
                        Capsule().fill(Tone.hairline).frame(width: 16, height: 4)
                        ForEach(0..<2, id: \.self) { row in
                            HStack(spacing: 0) {
                                ForEach(0..<3, id: \.self) { col in
                                    MiniPebble(height: 18, fill: Self.tint(month * 6 + row * 3 + col))
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 26)
        }
    }

    private static func tint(_ i: Int) -> Color {
        Color(hex: Tone.backdropWarm[i % Tone.backdropWarm.count]).opacity(0.8)
    }
}

private struct MiniHome: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Spacer().frame(height: 26)
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 8) {
                    MiniPebble(height: 16, fill: Tone.hairline)
                    Capsule().fill(Tone.hairline).frame(width: CGFloat(34 - i * 6), height: 5)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SwipeFinger: View {
    var body: some View {
        Circle()
            .fill(Tone.primary.opacity(0.85))
            .frame(width: 20, height: 20)
            .background(Circle().fill(Tone.primary.opacity(0.18)).frame(width: 38, height: 38))
    }
}

enum SwipeMotion {
    struct State: Equatable {
        var progress: Double
        var finger: Double
    }

    static let cycle = 3.8

    /// 손가락 나타남 · 쓸기 1초 · 손가락 걷힘 · 밀려 나온 면 머묾 · 되돌아감 · 쉼.
    static func state(at p: Double, moving: Bool) -> State {
        guard moving else { return State(progress: 0.6, finger: 1) }
        let appear = SceneEase.segment(p, from: 0, to: 0.3)
        let swipe = SceneEase.inOut(SceneEase.segment(p, from: 0.3, to: 1.3))
        let lift = SceneEase.segment(p, from: 1.3, to: 1.6)
        let back = SceneEase.inOut(SceneEase.segment(p, from: 2.7, to: 3.3))
        return State(progress: swipe * (1 - back), finger: appear * (1 - lift))
    }
}
