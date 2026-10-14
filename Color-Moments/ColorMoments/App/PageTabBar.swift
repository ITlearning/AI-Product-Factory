import SwiftUI

/// HomeShell.progress 의 자리 — 옆으로 민 칸 수.
enum ShellPage: CGFloat, CaseIterable {
    case camera = 1
    case home = 0
    case collection = -1
    case words = -2

    var progress: CGFloat { rawValue }

    init?(progress: CGFloat) { self.init(rawValue: progress) }
}

/// 칸 이동 계산 — progress 로 어느 칸인지, 놓았을 때 어디로 붙는지.
struct ShellPages: Equatable {
    /// 「말」 칸(1.2) — 화면이 생기기 전까지 끈다. 끄면 1.1 과 같은 두 칸.
    static let wordsTab = false
    static let live = ShellPages(words: wordsTab)

    static let commitDistance: CGFloat = 0.42
    /// UIKit 팬 속도(pt/s) — SwiftUI 쪽 commitVelocity 는 예상 이동 거리 차이라 단위가 다르다.
    static let flickVelocity: CGFloat = 500
    private static let band: CGFloat = 0.28

    let words: Bool

    var tabs: [ShellPage] { words ? [.home, .collection, .words] : [.home, .collection] }
    var last: ShellPage { words ? .words : .collection }

    func nearest(_ progress: CGFloat) -> ShellPage {
        let p = min(max(progress.rounded(.toNearestOrEven), last.progress), ShellPage.camera.progress)
        return ShellPage(progress: p + 0) ?? .home
    }

    func tab(at progress: CGFloat) -> ShellPage {
        let page = nearest(progress)
        return page == .camera ? .home : page
    }

    static func showsTabBar(_ progress: CGFloat) -> Bool { progress <= 0.01 }

    /// 홈에 정확히 멈췄을 때만 증정이 뜬다 — 애니메이션 중에도 값이 바로 바뀐다.
    static func holdsArrivals(_ progress: CGFloat) -> Bool { progress != 0 }

    static func acceptsTaps(_ page: ShellPage, progress: CGFloat, swiping: Bool) -> Bool {
        progress == page.progress && !swiping
    }

    func edgeSwipe(at page: ShellPage) -> CollectionSwipe.Mode {
        guard tabs.contains(page) else { return .off }
        return CollectionSwipe.Mode(forward: page.progress > last.progress, back: page != .home)
    }

    func swipeMode(progress: CGFloat, dragStart: CGFloat?, cameraDragging: Bool,
                   onboardingDone: Bool) -> CollectionSwipe.Mode {
        guard onboardingDone, !cameraDragging else { return .off }
        if let dragStart { return edgeSwipe(at: nearest(dragStart)) }
        guard let page = ShellPage(progress: progress) else { return .off }
        return edgeSwipe(at: page)
    }

    private func range(from start: ShellPage) -> ClosedRange<CGFloat> {
        max(last.progress, start.progress - 1)...min(ShellPage.home.progress, start.progress + 1)
    }

    func rubberBanded(_ x: CGFloat, from start: ShellPage) -> CGFloat {
        let r = range(from: start)
        if x > r.upperBound { return r.upperBound + (x - r.upperBound) * Self.band }
        if x < r.lowerBound { return r.lowerBound + (x - r.lowerBound) * Self.band }
        return x
    }

    func target(from start: ShellPage, progress p: CGFloat, velocity vx: CGFloat) -> ShellPage {
        let mode = edgeSwipe(at: start)
        let s = start.progress, d = p - s
        let c = Self.commitDistance, f = Self.flickVelocity
        let raw: CGFloat
        if mode.forward && mode.back {
            if vx > f { raw = p.rounded(.down) + 1 }
            else if vx < -f { raw = p.rounded(.up) - 1 }
            else { raw = d < -c ? s - 1 : (d > c ? s + 1 : s) }
        } else if mode.forward {
            raw = d < -c || vx < -f ? s - 1 : s
        } else if mode.back {
            raw = d > c || vx > f ? s + 1 : s
        } else {
            raw = s
        }
        let r = range(from: start)
        return ShellPage(progress: min(max(raw, r.lowerBound), r.upperBound) + 0) ?? start
    }
}

/// 아래 탭바 — 왼쪽 동그란 카메라 버튼(카메라가 왼쪽에서 들어오니 왼쪽에), 캡슐은 홈 · 조약돌 · 말.
/// 누르면 스와이프처럼 옆으로 밀려 넘어간다(HomeShell 이 progress 를 옮긴다). iOS 26 은 리퀴드 글래스, 그 전은 반투명 재질.
struct PageTabBar: View {
    let tabs: [ShellPage]
    let selected: ShellPage
    /// 아래로 스크롤하는 동안 — 문구를 거두고 조금 작아진다. 칸과 카메라는 그대로 남긴다.
    let folded: Bool
    let select: (ShellPage) -> Void
    let camera: () -> Void

    @Namespace private var selection

    var body: some View {
        HStack(spacing: folded ? 8 : 10) {
            Button(action: camera) {
                Image(systemName: "camera.fill")
                    .font(.system(size: folded ? 15 : 17, weight: .semibold))
                    .foregroundStyle(Tone.primary)
                    .frame(width: folded ? 44 : 50, height: folded ? 44 : 50)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .modifier(Glass(shape: Circle()))
            .accessibilityLabel("카메라")

            HStack(spacing: 2) {
                ForEach(tabs, id: \.self) { page in
                    item(title(page), icon: icon(page), selected: page == selected) { select(page) }
                }
            }
            .padding(4)
            .modifier(Glass(shape: Capsule()))
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selected)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: folded)
        .padding(.bottom, 4)
    }

    private func title(_ page: ShellPage) -> String {
        switch page {
        case .camera: "카메라"
        case .home: "홈"
        case .collection: tabs.count > 2 ? "조약돌" : "모은 조약돌"
        case .words: "말"
        }
    }

    private func icon(_ page: ShellPage) -> String {
        switch page {
        case .camera: "camera"
        case .home: "house"
        case .collection: "circle.grid.2x2"
        case .words: "quote.bubble"
        }
    }

    private func item(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // 문구를 빼지 않고 제자리에서 흐리게 — 빼면 사라지는 동안 옛 자리에 남아 칸이 줄 때 옆으로 밀려 보인다.
            // 접힐 땐 문구가 먼저 빠르게 흐려지고, 펼 땐 칸이 넓어진 뒤 떠오른다.
            VStack(spacing: folded ? 0 : 3) {
                Image(systemName: selected ? "\(icon).fill" : icon)
                    .font(.system(size: 17))
                Text(title).font(Face.tab).fixedSize()
                    .opacity(folded ? 0 : 1)
                    .blur(radius: folded ? 2 : 0)
                    .scaleEffect(folded ? 0.8 : 1, anchor: .top)
                    .animation(folded ? .easeOut(duration: 0.12) : .easeOut(duration: 0.22).delay(0.1), value: folded)
                    .frame(height: folded ? 0 : nil)
            }
            .foregroundStyle(selected ? Tone.primary : Tone.tertiary)
            .frame(width: tabs.count > 2 ? (folded ? 56 : 84) : (folded ? 64 : 96), height: folded ? 44 : 50)
            .background {
                if selected {
                    Capsule().fill(.white.opacity(0.12)).matchedGeometryEffect(id: "selected", in: selection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct Glass<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.08), lineWidth: 0.5))
        }
    }
}

/// 스크롤 방향으로 탭바를 접고 편다 — 맨 위 근처는 늘 편다.
enum TabBarFold {
    static func report(old: CGFloat, new: CGFloat, to fold: (Bool) -> Void) {
        if new < 60 { fold(false) }
        else if new - old > 3 { fold(true) }
        else if old - new > 3 { fold(false) }
    }
}
