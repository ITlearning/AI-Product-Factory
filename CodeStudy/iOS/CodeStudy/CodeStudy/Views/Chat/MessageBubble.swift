import SwiftUI

struct MessageBubble: View {
    let message: ChatMessageUI

    // Design tokens
    private let userBubbleColor = Color(hex: "1E3A5F")
    private let aiBubbleColor = Color(.systemGray6)
    private let maxWidthFraction: CGFloat = 0.80
    private let cornerRadius: CGFloat = 16

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: UIScreen.main.bounds.width * (1 - maxWidthFraction)) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if isUser {
                    userContent
                } else {
                    assistantContent
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isUser ? userBubbleColor : aiBubbleColor)
            .clipShape(BubbleShape(isUser: isUser, cornerRadius: cornerRadius))

            if !isUser { Spacer(minLength: UIScreen.main.bounds.width * (1 - maxWidthFraction)) }
        }
    }

    // MARK: - User content

    @ViewBuilder
    private var userContent: some View {
        let segments = parseContent(message.content)
        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
            switch segment {
            case .text(let text):
                Text(markdownAttributed(text))
                    .font(.body)
                    .foregroundStyle(.white)
                    .tint(.white)
            case .code(let language, let code):
                codeBlock(language: language, code: code)
            }
        }
    }

    // MARK: - Assistant content

    @ViewBuilder
    private var assistantContent: some View {
        let segments = parseContent(message.content)
        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
            switch segment {
            case .text(let text):
                Text(markdownAttributed(text))
                    .font(.body)
                    .foregroundStyle(Color.primary)
            case .code(let language, let code):
                codeBlock(language: language, code: code)
            }
        }

        if message.isStreaming {
            StreamingCursor()
        }
    }

    // MARK: - Markdown renderer

    /// Parses inline markdown (**bold**, *italic*, `code`, [link](url)) into an AttributedString.
    /// Falls back to plain text if parsing fails or while streaming produces incomplete syntax.
    private func markdownAttributed(_ text: String) -> AttributedString {
        do {
            return try AttributedString(
                markdown: text,
                options: AttributedString.MarkdownParsingOptions(
                    allowsExtendedAttributes: false,
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )
        } catch {
            return AttributedString(text)
        }
    }

    // MARK: - Code block

    private func codeBlock(language: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !language.isEmpty {
                Text(language)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            // Horizontal scroll so long lines don't wrap or clip.
            ScrollView(.horizontal, showsIndicators: false) {
                Text(highlightedCode(code, language: language))
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(red: 0.117, green: 0.117, blue: 0.137))  // Xcode editor background
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    /// Returns a syntax-highlighted AttributedString for Swift, or a plain
    /// AttributedString for other languages.
    private func highlightedCode(_ code: String, language: String) -> AttributedString {
        let normalizedLang = language.lowercased()
        if normalizedLang.isEmpty || normalizedLang == "swift" {
            return SwiftSyntaxHighlighter.highlight(code)
        }
        var plain = AttributedString(code)
        plain.foregroundColor = SwiftSyntaxHighlighter.defaultColor
        plain.font = .system(.callout, design: .monospaced)
        return plain
    }

    // MARK: - Markdown-lite parser

    private enum ContentSegment {
        case text(String)
        case code(language: String, code: String)
    }

    private func parseContent(_ content: String) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        let parts = content.components(separatedBy: "```")

        for (index, part) in parts.enumerated() {
            if index % 2 == 0 {
                // Regular text
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    segments.append(.text(trimmed))
                }
            } else {
                // Code block — first line may be language identifier
                let lines = part.components(separatedBy: "\n")
                let language: String
                let code: String
                if let first = lines.first,
                   first.trimmingCharacters(in: .whitespaces).allSatisfy({ $0.isLetter }) &&
                   first.count < 20 {
                    language = first.trimmingCharacters(in: .whitespaces)
                    code = lines.dropFirst().joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    language = ""
                    code = part.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if !code.isEmpty {
                    segments.append(.code(language: language, code: code))
                }
            }
        }

        return segments
    }
}

// MARK: - Bubble shape with tail

struct BubbleShape: Shape {
    let isUser: Bool
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let tailSize: CGFloat = 6
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isUser
                ? [.topLeft, .topRight, .bottomLeft]
                : [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )

        // Small tail triangle
        let tailPath = UIBezierPath()
        if isUser {
            // Bottom-right tail
            tailPath.move(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY))
            tailPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY + tailSize))
            tailPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            // Bottom-left tail
            tailPath.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            tailPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY + tailSize))
            tailPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        tailPath.close()
        path.append(tailPath)

        return Path(path.cgPath)
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(message: ChatMessageUI(
            role: .user,
            content: "옵셔널이 뭔가요?"
        ))
        MessageBubble(message: ChatMessageUI(
            role: .assistant,
            content: "좋은 질문이에요! 먼저 생각해볼게요.\n\n```swift\nvar name: String? = nil\n```\n\n이 코드에서 `?`는 무엇을 의미할까요?"
        ))
        MessageBubble(message: ChatMessageUI(
            role: .assistant,
            content: "생각하는 중...",
            isStreaming: true
        ))
    }
    .padding()
}
