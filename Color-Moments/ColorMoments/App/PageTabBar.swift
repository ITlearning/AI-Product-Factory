import SwiftUI

/// 아래 탭바 — 왼쪽 동그란 카메라 버튼(카메라가 왼쪽에서 들어오니 왼쪽에), 캡슐은 홈 · 모은 조약돌.
/// 누르면 스와이프처럼 옆으로 밀려 넘어간다(HomeShell 이 progress 를 옮긴다). iOS 26 은 리퀴드 글래스, 그 전은 반투명 재질.
struct PageTabBar: View {
    let onCollection: Bool
    /// 아래로 스크롤하는 동안 — 고른 칸 아이콘 하나로 접는다. 누르면 펼친다. 카메라는 늘 남긴다(찍기가 편해야 한다).
    let folded: Bool
    let select: (_ collection: Bool) -> Void
    let expand: () -> Void
    let camera: () -> Void

    @Namespace private var selection

    var body: some View {
        HStack(spacing: 10) {
            Button(action: camera) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Tone.primary)
                    .frame(width: 50, height: 50)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .modifier(Glass(shape: Circle()))
            .accessibilityLabel("카메라")

            HStack(spacing: 2) {
                if folded {
                    Button(action: expand) {
                        Image(systemName: onCollection ? "circle.grid.2x2.fill" : "house.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Tone.primary)
                            .frame(width: 58, height: 42)
                            .background {
                                Capsule().fill(.white.opacity(0.12)).matchedGeometryEffect(id: "selected", in: selection)
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(onCollection ? "모은 조약돌" : "홈")
                } else {
                    item("홈", icon: "house", selected: !onCollection) { select(false) }
                    item("모은 조약돌", icon: "circle.grid.2x2", selected: onCollection) { select(true) }
                }
            }
            .padding(4)
            .modifier(Glass(shape: Capsule()))
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: onCollection)
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: folded)
        }
        .padding(.bottom, 4)
    }

    private func item(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: selected ? "\(icon).fill" : icon)
                    .font(.system(size: 17))
                Text(title).font(Face.tab)
            }
            .foregroundStyle(selected ? Tone.primary : Tone.tertiary)
            .frame(width: 96, height: 50)
            .background {
                if selected {
                    Capsule().fill(.white.opacity(0.12)).matchedGeometryEffect(id: "selected", in: selection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
