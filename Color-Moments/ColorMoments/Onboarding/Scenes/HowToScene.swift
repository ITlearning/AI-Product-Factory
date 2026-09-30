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

    private var camera: some View { CameraFace() }
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

private struct CameraFace: View {
    var body: some View {
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

/// 카메라 컨트롤 — 옆면 버튼을 누르면 잠든 화면에 카메라가 켜진다.
struct CameraButtonScene: View {

    private static let width: CGFloat = 108

    var body: some View {
        SceneClock { t, moving in
            let s = ButtonMotion.state(at: t.truncatingRemainder(dividingBy: ButtonMotion.cycle), moving: moving)
            PhoneSilhouette(width: Self.width) {
                ZStack {
                    Rectangle().fill(Tone.pure)
                    CameraFace().opacity(s.camera)
                }
            }
            .overlay(alignment: .trailing) {
                ZStack {
                    Capsule().fill(Tone.secondary).frame(width: 4, height: 24)
                    Circle()
                        .fill(Tone.primary.opacity(0.85))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Tone.primary.opacity(0.18)).frame(width: 34, height: 34))
                        .offset(x: 16 - 7 * s.press)
                        .opacity(s.finger)
                }
                .offset(x: 3, y: 28)
            }
        }
        .accessibilityHidden(true)
    }
}

enum ButtonMotion {
    struct State: Equatable {
        var press: Double
        var finger: Double
        var camera: Double
    }

    static let cycle = 3.4

    /// 손가락 나타남 · 누름 · 카메라 켜짐 · 손가락 걷힘 · 카메라 머묾 · 꺼짐 · 쉼.
    static func state(at p: Double, moving: Bool) -> State {
        guard moving else { return State(press: 1, finger: 1, camera: 1) }
        let appear = SceneEase.segment(p, from: 0, to: 0.3)
        let press = SceneEase.inOut(SceneEase.segment(p, from: 0.4, to: 0.6))
        let release = SceneEase.segment(p, from: 0.75, to: 0.95)
        let lift = SceneEase.segment(p, from: 1.1, to: 1.4)
        let on = SceneEase.inOut(SceneEase.segment(p, from: 0.6, to: 1.0))
        let off = SceneEase.inOut(SceneEase.segment(p, from: 2.6, to: 3.0))
        return State(press: press * (1 - release), finger: appear * (1 - lift), camera: on * (1 - off))
    }
}

/// 사진이 없는 날 알림 — 아침 하늘에 알림이 톡 내려오고 찰칵, 하늘이 노을로 물들면 또 톡, 찰칵.
struct ReminderScene: View {

    private static let width: CGFloat = 108
    private static let cycle = 6.4
    private static let morning = (top: Color(hex: "#9CC6E8"), bottom: Color(hex: "#F6DDBF"))
    private static let dusk = (top: Color(hex: "#5B4C8A"), bottom: Color(hex: "#F08A5D"))

    var body: some View {
        SceneClock { t, moving in
            let p = moving ? t.truncatingRemainder(dividingBy: Self.cycle) : 4.4
            let evening = SceneEase.inOut(SceneEase.segment(p, from: 2.9, to: 3.5))
                * (1 - SceneEase.inOut(SceneEase.segment(p, from: 6.0, to: 6.4)))
            let local = p < 3.2 ? p : p - 3.2
            let banner = moving
                ? SceneEase.outBack(SceneEase.segment(local, from: 0.3, to: 0.7)) * (1 - SceneEase.segment(local, from: 1.7, to: 2.0))
                : 1
            let flash = moving ? max(0, 1 - abs(local - 2.25) / 0.12) : 0
            PhoneSilhouette(width: Self.width) {
                GeometryReader { geo in
                    let h = geo.size.height
                    ZStack(alignment: .top) {
                        LinearGradient(colors: [Self.morning.top.mix(with: Self.dusk.top, by: evening),
                                                Self.morning.bottom.mix(with: Self.dusk.bottom, by: evening)],
                                       startPoint: .top, endPoint: .bottom)
                        Circle()
                            .fill(Color(hex: "#FFF3D6").mix(with: Color(hex: "#FFB36B"), by: evening))
                            .frame(width: 22, height: 22)
                            .blur(radius: 1)
                            .offset(x: -18 + 30 * evening, y: h * (0.42 + 0.26 * evening))
                        HStack(spacing: 5) {
                            Circle().fill(Tone.pure.opacity(0.7)).frame(width: 9, height: 9)
                            VStack(alignment: .leading, spacing: 3) {
                                Capsule().fill(Tone.pure.opacity(0.55)).frame(width: 34, height: 3)
                                Capsule().fill(Tone.pure.opacity(0.35)).frame(width: 24, height: 3)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white.opacity(0.85)))
                        .padding(.horizontal, 6)
                        .offset(y: -26 + 36 * banner)
                        .opacity(min(1, banner * 1.5))
                        Color.white.opacity(0.85 * flash)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
