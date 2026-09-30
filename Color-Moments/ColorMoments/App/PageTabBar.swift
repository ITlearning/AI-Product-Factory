import SwiftUI

/// 아래 탭바 — 왼쪽 동그란 카메라 버튼(카메라가 왼쪽에서 들어오니 왼쪽에), 캡슐은 홈 · 모은 조약돌.
/// 누르면 스와이프처럼 옆으로 밀려 넘어간다(HomeShell 이 progress 를 옮긴다). iOS 26 은 리퀴드 글래스, 그 전은 반투명 재질.
struct PageTabBar: View {
    let onCollection: Bool
    /// 아래로 스크롤하는 동안 — 문구를 거두고 조금 작아진다. 두 칸과 카메라는 그대로 남긴다.
    let folded: Bool
    let select: (_ collection: Bool) -> Void
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
                item("홈", icon: "house", selected: !onCollection) { select(false) }
                item("모은 조약돌", icon: "circle.grid.2x2", selected: onCollection) { select(true) }
            }
            .padding(4)
            .modifier(Glass(shape: Capsule()))
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: onCollection)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: folded)
        .padding(.bottom, 4)
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
            .frame(width: folded ? 64 : 96, height: folded ? 44 : 50)
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
