import SwiftUI

/// 아래 탭바 — 왼쪽 동그란 카메라 버튼(카메라가 왼쪽에서 들어오니 왼쪽에), 캡슐은 홈 · 모은 조약돌.
/// 누르면 스와이프처럼 옆으로 밀려 넘어간다(HomeShell 이 progress 를 옮긴다). iOS 26 은 리퀴드 글래스, 그 전은 반투명 재질.
struct PageTabBar: View {
    let onCollection: Bool
    let select: (_ collection: Bool) -> Void
    let camera: () -> Void

    @Namespace private var selection

    var body: some View {
        HStack(spacing: 10) {
            Button(action: camera) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Tone.primary)
                    .frame(width: 58, height: 58)
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
