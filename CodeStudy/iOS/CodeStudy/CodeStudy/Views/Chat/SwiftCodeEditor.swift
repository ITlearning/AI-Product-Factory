import SwiftUI
import UIKit

/// A UITextView-backed code editor with live Swift syntax highlighting.
///
/// Wraps UITextView in a UIViewRepresentable so we can control cursor
/// position, attributed text, and keyboard behavior precisely. Used inside
/// MessageInputBar when the user toggles code input mode.
///
/// Key behaviors:
/// - Monospace font, dark Xcode-like background
/// - Autocorrect / smart punctuation / capitalization all disabled
/// - Re-runs SwiftSyntaxHighlighter on every text change
/// - Preserves cursor position after re-highlighting
/// - Sizing is controlled by the caller via `.frame(minHeight:maxHeight:)`.
///   The text view scrolls internally when content exceeds the frame —
///   we intentionally do NOT implement `sizeThatFits` here because it
///   would fight SwiftUI's frame modifier in the caller.
/// - Auto-focuses once on first appearance (so toggling code mode opens the keyboard)
///
/// Note on focus: this view intentionally does NOT accept a SwiftUI focus binding.
/// SwiftUI's `@FocusState` does not automatically track UIKit's first-responder
/// state, so reading a stale `Bool` during `updateUIView` would resign the
/// first responder on every keystroke (because `textViewDidChange` writes back
/// to the `text` binding, which triggers another `updateUIView` pass). Instead
/// we let UIKit own focus: tapping the text view focuses it naturally, and the
/// caller can auto-focus on mode entry via `.onAppear` if desired.
struct SwiftCodeEditor: UIViewRepresentable {
    @Binding var text: String

    /// When true, the text view becomes first responder on first appearance.
    var autoFocusOnAppear: Bool = true

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator

        // Appearance
        textView.backgroundColor = SwiftSyntaxHighlighter.uiBackgroundColor
        textView.tintColor = SwiftSyntaxHighlighter.uiCaretColor
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.layer.cornerRadius = 12
        textView.clipsToBounds = true

        // Keyboard / input behavior — critical for code input
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.keyboardType = .asciiCapable
        textView.returnKeyType = .default

        // Sizing: the caller controls height via `.frame(minHeight:maxHeight:)`.
        // We enable internal scrolling so overflow content stays inside the
        // frame instead of pushing the parent layout around. We keep the
        // default `textContainer.lineFragmentPadding` (5) to avoid subtle
        // layout-manager weirdness.
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true

        // Initial content
        textView.attributedText = SwiftSyntaxHighlighter.highlightForUIKit(text)

        // One-shot auto-focus: schedule becomeFirstResponder on the next
        // runloop so the view is in the hierarchy and UIKit accepts focus.
        if autoFocusOnAppear {
            DispatchQueue.main.async {
                if !textView.isFirstResponder {
                    textView.becomeFirstResponder()
                }
            }
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only rewrite attributedText when the external binding value
        // diverges from the view's current text. This happens on things
        // like "clear after send", not during user typing (typing is
        // handled in textViewDidChange).
        //
        // Important: we intentionally do NOT touch first-responder state here.
        // Any becomeFirstResponder / resignFirstResponder call based on an
        // external Bool would fight UIKit (see struct doc comment above) and
        // cause the keyboard to dismiss after every keystroke.
        let currentPlain = uiView.text ?? ""
        if currentPlain != text {
            let selectedRange = uiView.selectedRange
            uiView.attributedText = SwiftSyntaxHighlighter.highlightForUIKit(text)
            // Clamp the selection if the text shrank
            let newLength = (text as NSString).length
            let safeLocation = min(selectedRange.location, newLength)
            let safeLength = min(selectedRange.length, newLength - safeLocation)
            uiView.selectedRange = NSRange(location: safeLocation, length: max(0, safeLength))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SwiftCodeEditor
        private var isUpdatingFromHighlighter = false

        init(_ parent: SwiftCodeEditor) {
            self.parent = parent
        }

        // MARK: - Key interception (Enter / closing brace)

        /// Intercepts certain keystrokes to provide auto-indentation and
        /// auto-pairing. See `SwiftAutoIndent` for the pure logic.
        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            // Only single-char inserts are considered. Paste / multi-char
            // replacements fall through to UIKit's default behavior.
            guard text.count == 1, range.length == 0 else {
                return true
            }

            // Enter — auto-indent
            if text == "\n" {
                return !handleEnter(in: textView, at: range.location)
            }

            let inputChar = Character(text)
            let fullText = (textView.text ?? "") as NSString
            let cursor = range.location
            let nextChar: Character? = {
                guard cursor < fullText.length else { return nil }
                return Character(fullText.substring(with: NSRange(location: cursor, length: 1)))
            }()

            // 1. Skip-over: user types a closing char and it's already there.
            //    e.g. `print("hello|")` + `)` → cursor advances past `)`.
            if SwiftAutoIndent.shouldSkipClosingChar(inputChar: inputChar, nextChar: nextChar) {
                textView.selectedRange = NSRange(location: cursor + 1, length: 0)
                return false
            }

            // 2. `}` — if not skipped above, try auto-unindent on whitespace-only line
            if inputChar == "}" {
                return !handleClosingBrace(in: textView, at: cursor)
            }

            // 3. Auto-pair: `(`, `[`, `{`, `"`
            if let pair = SwiftAutoIndent.handleAutoPair(
                inputChar: inputChar,
                prevLine: lineText(before: cursor, in: fullText)
            ) {
                return !insertAutoPair(pair, in: textView, at: cursor)
            }

            return true
        }

        /// Insert an auto-paired string (e.g. `"()"`) and position the cursor
        /// between the pair. Returns true if the insertion was consumed.
        private func insertAutoPair(
            _ pair: SwiftAutoIndent.AutoPairResult,
            in textView: UITextView,
            at cursor: Int
        ) -> Bool {
            guard let uiRange = textView.uiTextRange(for: NSRange(location: cursor, length: 0)) else {
                return false
            }
            textView.replace(uiRange, withText: pair.insertion)
            let newLocation = cursor + pair.cursorOffsetInInsertion
            textView.selectedRange = NSRange(location: newLocation, length: 0)
            textViewDidChange(textView)
            return true
        }

        /// Handles an Enter key press. Returns true if we consumed the event
        /// (i.e. already inserted our custom text and the delegate should
        /// return `false` to cancel the default insertion).
        private func handleEnter(in textView: UITextView, at cursor: Int) -> Bool {
            let fullText = (textView.text ?? "") as NSString
            let prevLine = lineText(before: cursor, in: fullText)
            let nextChar: Character? = {
                guard cursor < fullText.length else { return nil }
                return Character(fullText.substring(with: NSRange(location: cursor, length: 1)))
            }()

            let result = SwiftAutoIndent.handleEnter(prevLine: prevLine, nextChar: nextChar)

            // Perform the replacement using UITextInput API to preserve undo
            guard let uiRange = textView.uiTextRange(for: NSRange(location: cursor, length: 0)) else {
                return false
            }
            textView.replace(uiRange, withText: result.insertion)

            // Position the cursor
            let newLocation = cursor + result.cursorOffsetInInsertion
            textView.selectedRange = NSRange(location: newLocation, length: 0)

            // Drive the existing pipeline (binding + highlighter)
            textViewDidChange(textView)
            return true
        }

        /// Handles a `}` key press. If the cursor sits at the end of a
        /// pure-whitespace line with >= 4 leading spaces, we remove 4 spaces
        /// and insert `}` at the outer indent. Otherwise fall through.
        private func handleClosingBrace(in textView: UITextView, at cursor: Int) -> Bool {
            let fullText = (textView.text ?? "") as NSString
            let prevLine = lineText(before: cursor, in: fullText)

            let result = SwiftAutoIndent.handleClosingBrace(prevLine: prevLine)
            if result.deleteBefore == 0 {
                // Normal insertion — let UIKit handle it
                return false
            }

            // Delete the leading spaces then insert "}"
            let deleteStart = cursor - result.deleteBefore
            let deleteRange = NSRange(location: deleteStart, length: result.deleteBefore)
            guard let uiDeleteRange = textView.uiTextRange(for: deleteRange) else {
                return false
            }
            textView.replace(uiDeleteRange, withText: result.insertion)
            textView.selectedRange = NSRange(location: deleteStart + 1, length: 0)

            textViewDidChange(textView)
            return true
        }

        /// Returns the text of the line the cursor is on, from the start of
        /// that line up to (but not including) `cursor`.
        private func lineText(before cursor: Int, in fullText: NSString) -> String {
            var lineStart = 0
            if cursor > 0 {
                let searchRange = NSRange(location: 0, length: cursor)
                let newlineRange = fullText.range(
                    of: "\n",
                    options: .backwards,
                    range: searchRange
                )
                if newlineRange.location != NSNotFound {
                    lineStart = newlineRange.location + 1
                }
            }
            return fullText.substring(with: NSRange(location: lineStart, length: cursor - lineStart))
        }

        // MARK: - Text change pipeline

        func textViewDidChange(_ textView: UITextView) {
            // Guard against recursion from our own attributedText re-assignment
            guard !isUpdatingFromHighlighter else { return }

            let plainText = textView.text ?? ""
            let selectedRange = textView.selectedRange

            // 1. Propagate plain text to parent binding first
            if parent.text != plainText {
                parent.text = plainText
            }

            // 2. Re-highlight and re-apply to the text view while preserving cursor
            let newAttributed = SwiftSyntaxHighlighter.highlightForUIKit(plainText)

            isUpdatingFromHighlighter = true
            // Save and restore typing attributes so the next character typed
            // inherits the correct base font/color (default tint, not last-keyword color).
            let typingAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 16, weight: .regular),
                .foregroundColor: SwiftSyntaxHighlighter.uiDefaultColor,
            ]
            textView.attributedText = newAttributed
            textView.selectedRange = selectedRange
            textView.typingAttributes = typingAttrs
            isUpdatingFromHighlighter = false
        }
    }
}

// MARK: - UITextView helper

private extension UITextView {
    /// Convert an NSRange into a UITextRange for use with `replace(_:withText:)`,
    /// which preserves the undo stack (unlike directly mutating `textStorage`).
    func uiTextRange(for nsRange: NSRange) -> UITextRange? {
        guard
            let start = position(from: beginningOfDocument, offset: nsRange.location),
            let end = position(from: start, offset: nsRange.length)
        else { return nil }
        return textRange(from: start, to: end)
    }
}

#Preview {
    @Previewable @State var code = "func greet(name: String) -> String {\n    return \"Hello, \\(name)!\"\n}"
    VStack {
        SwiftCodeEditor(text: $code, autoFocusOnAppear: false)
            .frame(minHeight: 100, maxHeight: 200)
            .padding()
        Spacer()
    }
}
