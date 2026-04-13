import SwiftUI

struct ActionButtonBar: View {
    let onAction: (ActionHint) -> Void

    // Design tokens
    private let accentColor = Color.warmOrange

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                actionPill(
                    title: String(localized: "action.simpler", defaultValue: "더 쉽게"),
                    icon: "arrow.down.circle",
                    hint: .simpler
                )
                actionPill(
                    title: String(localized: "action.hint", defaultValue: "힌트"),
                    icon: "lightbulb",
                    hint: .hint
                )
                actionPill(
                    title: String(localized: "action.quiz", defaultValue: "퀴즈"),
                    icon: "questionmark.circle",
                    hint: .quiz
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func actionPill(title: String, icon: String, hint: ActionHint) -> some View {
        Button {
            onAction(hint)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .strokeBorder(accentColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ActionButtonBar { hint in
        print("Tapped: \(hint)")
    }
}
