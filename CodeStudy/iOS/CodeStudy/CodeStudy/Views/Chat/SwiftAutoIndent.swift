import Foundation

/// Pure-function auto-indentation logic for the Swift code editor.
///
/// Kept separate from SwiftCodeEditor so it can be unit-tested without
/// involving UITextView. The algorithm is the "hybrid" design:
///
/// - Inspects only the **previous line** (O(line length), not O(document))
/// - Runs a 3-state machine over that line to correctly ignore braces inside
///   string literals and `//` line comments
/// - If the last non-whitespace character in "normal" state is `{`, indent +4
/// - If the character right after the cursor is `}`, performs a brace-expand
///   (inserts a blank line at the inner indent and pushes `}` to outer indent)
/// - If the user types `}` on a pure-whitespace line, auto-unindents by 4
///
/// Known limitations (documented, not bugs):
/// - Multi-line string literals (`"""..."""`) — treated as toggles, harmless
///   within a single-line scan
/// - Raw strings (`#"..."#`) — `#` ignored; rare in beginner snippets
/// - Block comments (`/* */`) — only line comments are stripped
/// - These are all acceptable for a chat code input used by Swift beginners.
enum SwiftAutoIndent {

    /// Number of spaces per indent level.
    static let indentUnit = 4

    // MARK: - Public API

    /// Result of the Enter key handler — describes the text to insert and
    /// where the cursor should end up relative to the start of the insertion.
    struct EnterResult: Equatable {
        /// The text to insert in place of the newline (e.g. `"\n    "` or
        /// for brace-expand, `"\n        \n    "`).
        let insertion: String
        /// Where the cursor should land, measured as an offset from the
        /// START of the insertion string. For brace-expand this is on the
        /// middle (inner) line.
        let cursorOffsetInInsertion: Int
    }

    /// Compute the appropriate insertion for an Enter key press.
    ///
    /// - Parameters:
    ///   - prevLine: The text of the line the cursor is currently on, from
    ///     the start of that line up to the cursor position (exclusive).
    ///   - nextChar: The character immediately AFTER the cursor, or nil if
    ///     the cursor is at the end of the document.
    /// - Returns: The text to insert and the cursor offset within it.
    static func handleEnter(prevLine: String, nextChar: Character?) -> EnterResult {
        let prevIndent = leadingSpaces(in: prevLine)
        let opensBlock = lastNonWhitespaceInNormalState(of: prevLine) == "{"

        let newIndent = opensBlock ? prevIndent + indentUnit : prevIndent
        let newIndentStr = String(repeating: " ", count: newIndent)

        if opensBlock && nextChar == "}" {
            // Brace-expand:
            //   before:  func foo() {|}
            //   after:   func foo() {
            //                |
            //            }
            let outerIndentStr = String(repeating: " ", count: prevIndent)
            let insertion = "\n" + newIndentStr + "\n" + outerIndentStr
            // Cursor lands after the first newline + inner indent
            let cursorOffset = 1 + newIndentStr.count
            return EnterResult(insertion: insertion, cursorOffsetInInsertion: cursorOffset)
        }

        let insertion = "\n" + newIndentStr
        return EnterResult(insertion: insertion, cursorOffsetInInsertion: insertion.count)
    }

    /// Result of the closing-brace handler — either "insert as normal" or
    /// "replace leading spaces + insert brace at outer indent."
    struct CloseBraceResult: Equatable {
        /// How many characters BEFORE the cursor to delete (always 4 or 0).
        let deleteBefore: Int
        /// The string to insert at the resulting position (always "}").
        let insertion: String
    }

    /// Compute the action for a `}` key press.
    ///
    /// Only auto-unindents when the cursor is at the END of a line whose
    /// leading content is **pure whitespace** with at least `indentUnit`
    /// spaces. Otherwise returns a no-op unindent (just insert `}`).
    ///
    /// - Parameter prevLine: The text from the start of the current line
    ///   up to the cursor (same as for `handleEnter`).
    static func handleClosingBrace(prevLine: String) -> CloseBraceResult {
        // Must be all whitespace up to the cursor on this line
        guard prevLine.allSatisfy({ $0 == " " || $0 == "\t" }) else {
            return CloseBraceResult(deleteBefore: 0, insertion: "}")
        }
        let leadingCount = prevLine.count
        guard leadingCount >= indentUnit else {
            return CloseBraceResult(deleteBefore: 0, insertion: "}")
        }
        return CloseBraceResult(deleteBefore: indentUnit, insertion: "}")
    }

    // MARK: - Auto-pairing: ( [ { "

    /// Result of an auto-pair insertion, e.g. typing `(` produces `()` with
    /// the cursor landing between them.
    struct AutoPairResult: Equatable {
        /// The full string to insert, e.g. "()" or "\"\"".
        let insertion: String
        /// Where the cursor should end up, relative to the start of `insertion`.
        /// For a standard pair this is always 1 (right after the open char).
        let cursorOffsetInInsertion: Int
    }

    /// Given the character the user just typed and the text on the current
    /// line up to the cursor, decide whether to auto-insert a matching pair.
    ///
    /// Returns nil if the input is not a pairable character, or if we're
    /// currently inside a string literal / line comment (where auto-pairing
    /// would fight the user).
    static func handleAutoPair(inputChar: Character, prevLine: String) -> AutoPairResult? {
        // Don't auto-pair inside strings or line comments.
        // Exception: we still allow `"` to CLOSE a string — but that case is
        // handled naturally because the user tapping `"` while inside a
        // string gets skipped by `shouldSkipClosingChar` (see below) when
        // the next char is `"`.
        let inside = isInsideStringOrComment(prevLine)

        switch inputChar {
        case "(":
            return inside ? nil : AutoPairResult(insertion: "()", cursorOffsetInInsertion: 1)
        case "[":
            return inside ? nil : AutoPairResult(insertion: "[]", cursorOffsetInInsertion: 1)
        case "{":
            return inside ? nil : AutoPairResult(insertion: "{}", cursorOffsetInInsertion: 1)
        case "\"":
            // Only pair quotes when OUTSIDE a string (otherwise we'd insert
            // `""` at the end of "hello|" giving "hello""").
            return inside ? nil : AutoPairResult(insertion: "\"\"", cursorOffsetInInsertion: 1)
        default:
            return nil
        }
    }

    /// Decide whether a closing character input should be "skipped over" —
    /// i.e. the user typed `)` and the next character is already `)`, so
    /// we just advance the cursor past it instead of inserting another.
    ///
    /// This makes auto-paired `()` / `[]` / `{}` / `""` feel natural.
    static func shouldSkipClosingChar(inputChar: Character, nextChar: Character?) -> Bool {
        guard let next = nextChar else { return false }
        let closers: Set<Character> = [")", "]", "}", "\""]
        return closers.contains(inputChar) && inputChar == next
    }

    /// Returns true if the cursor position (end of `prevLine`) is currently
    /// inside a string literal or a `//` line comment.
    static func isInsideStringOrComment(_ prevLine: String) -> Bool {
        enum State { case normal, inString }
        var state: State = .normal

        let chars = Array(prevLine)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            switch state {
            case .normal:
                // Line comment — everything after is "inside"
                if c == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
                    return true
                }
                if c == "\"" {
                    state = .inString
                }
            case .inString:
                if c == "\\" {
                    i += 1  // skip escaped char
                } else if c == "\"" {
                    state = .normal
                }
            }
            i += 1
        }
        return state == .inString
    }

    // MARK: - Internals (exposed for tests)

    /// Count the number of leading space characters in a line.
    /// Tabs are normalized to 4 spaces (chat snippets rarely contain tabs,
    /// but we want deterministic behavior if one slips in).
    static func leadingSpaces(in line: String) -> Int {
        var count = 0
        for c in line {
            if c == " " {
                count += 1
            } else if c == "\t" {
                count += indentUnit
            } else {
                break
            }
        }
        return count
    }

    /// Scan a single line with a 3-state machine and return the LAST
    /// non-whitespace character that occurred while in "normal" state.
    /// String literals and `//` line comments are skipped.
    ///
    /// Returns nil for an all-whitespace or all-comment line.
    static func lastNonWhitespaceInNormalState(of line: String) -> Character? {
        enum State { case normal, inString }
        var state: State = .normal
        var lastNonWS: Character? = nil

        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            switch state {
            case .normal:
                // Check for line comment start — everything after is dead
                if c == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
                    return lastNonWS
                }
                if c == "\"" {
                    state = .inString
                } else if c != " " && c != "\t" {
                    lastNonWS = c
                }
            case .inString:
                if c == "\\" {
                    // Skip the escaped character (if any)
                    i += 1
                } else if c == "\"" {
                    state = .normal
                }
            }
            i += 1
        }
        return lastNonWS
    }
}
