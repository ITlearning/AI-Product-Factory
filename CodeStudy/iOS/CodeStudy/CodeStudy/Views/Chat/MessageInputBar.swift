import SwiftUI

struct MessageInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    // Design tokens
    private let accentColor = Color(hex: "FF6B35")
    private let sendButtonSize: CGFloat = 36

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    String(localized: "input.placeholder", defaultValue: "메시지를 입력하세요..."),
                    text: $text,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.body)
                .focused(isFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit {
                    if canSend { onSend() }
                }

                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: sendButtonSize, height: sendButtonSize)
                        .background(canSend ? accentColor : Color.gray.opacity(0.4))
                        .clipShape(Circle())
                }
                .disabled(!canSend)
                .animation(.easeInOut(duration: 0.15), value: canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @FocusState var focused: Bool

    VStack {
        Spacer()
        MessageInputBar(
            text: $text,
            isStreaming: false,
            isFocused: $focused,
            onSend: { print("Send: \(text)") }
        )
    }
}
