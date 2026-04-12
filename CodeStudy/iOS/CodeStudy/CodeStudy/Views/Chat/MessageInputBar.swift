import SwiftUI

struct MessageInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    var isFocused: FocusState<Bool>.Binding
    @Binding var isCodeMode: Bool
    let onSend: () -> Void

    // Code input mode — when enabled, input is treated as Swift code:
    // monospace font, no autocorrect, no auto-capitalize, and on send the
    // text is wrapped in ```swift ... ``` markdown fence.
    // Controlled by the parent so AI responses can auto-toggle it.

    // Design tokens
    private let accentColor = Color(hex: "FF6B35")
    private let codeBgColor = Color(red: 0.117, green: 0.117, blue: 0.137)
    private let sendButtonSize: CGFloat = 36
    private let toggleButtonSize: CGFloat = 36

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 8) {
                // Code mode toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCodeMode.toggle()
                    }
                } label: {
                    Image(systemName: isCodeMode ? "chevron.left.forwardslash.chevron.right" : "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isCodeMode ? .white : accentColor)
                        .frame(width: toggleButtonSize, height: toggleButtonSize)
                        .background(isCodeMode ? accentColor : Color.clear)
                        .overlay(
                            Circle()
                                .strokeBorder(accentColor, lineWidth: isCodeMode ? 0 : 1.5)
                        )
                        .clipShape(Circle())
                }

                // Text input
                inputField

                // Send button
                Button(action: handleSend) {
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

    // MARK: - Input field (normal vs code mode)

    @ViewBuilder
    private var inputField: some View {
        if isCodeMode {
            // Live syntax-highlighted Swift code editor.
            // SwiftCodeEditor owns its own focus: it auto-focuses when it
            // first appears (entering code mode) and UIKit handles taps
            // naturally afterwards. We intentionally don't pass the SwiftUI
            // FocusState down — see SwiftCodeEditor's doc comment for why
            // syncing a Bool back to UIKit's first responder causes the
            // keyboard to dismiss on every keystroke.
            SwiftCodeEditor(text: $text)
                .frame(minHeight: 60, maxHeight: 180)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        // Match SwiftCodeEditor's text origin exactly:
                        // textContainerInset.top = 10, textContainerInset.left = 10,
                        // lineFragmentPadding = 5 (UIKit default).
                        // So the first glyph's baseline starts at (15, 10).
                        Text(String(
                            localized: "input.placeholder.code",
                            defaultValue: "Swift 코드를 입력하세요..."
                        ))
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(.leading, 15)
                        .padding(.top, 10)
                        .allowsHitTesting(false)
                    }
                }
        } else {
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
                if canSend { handleSend() }
            }
        }
    }

    // MARK: - Send

    private func handleSend() {
        guard canSend else { return }
        if isCodeMode {
            // Wrap code in markdown fence so the AI interprets it as Swift code
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            text = "```swift\n\(trimmed)\n```"
        }
        onSend()
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @State var isCodeMode = false
    @Previewable @FocusState var focused: Bool

    VStack {
        Spacer()
        MessageInputBar(
            text: $text,
            isStreaming: false,
            isFocused: $focused,
            isCodeMode: $isCodeMode,
            onSend: { print("Send: \(text)") }
        )
    }
}
