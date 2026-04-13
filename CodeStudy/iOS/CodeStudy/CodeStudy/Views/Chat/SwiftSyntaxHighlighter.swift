import SwiftUI
import UIKit

/// Lightweight regex-based Swift syntax highlighter.
/// Zero external dependencies — uses NSRegularExpression + AttributedString.
/// Color palette matches Xcode's default Dark theme approximately.
enum SwiftSyntaxHighlighter {

    // MARK: - UIKit color tokens (for UITextView-based live editor)

    static let uiKeywordColor = UIColor(red: 0.988, green: 0.373, blue: 0.639, alpha: 1.0)
    static let uiStringColor = UIColor(red: 0.988, green: 0.416, blue: 0.365, alpha: 1.0)
    static let uiCommentColor = UIColor(red: 0.424, green: 0.475, blue: 0.525, alpha: 1.0)
    static let uiTypeColor = UIColor(red: 0.816, green: 0.659, blue: 1.0, alpha: 1.0)
    static let uiNumberColor = UIColor(red: 0.816, green: 0.749, blue: 0.412, alpha: 1.0)
    static let uiDefaultColor = UIColor(red: 0.878, green: 0.878, blue: 0.878, alpha: 1.0)
    static let uiBackgroundColor = UIColor(red: 0.117, green: 0.117, blue: 0.137, alpha: 1.0)
    static let uiCaretColor = UIColor(red: 0.988, green: 0.373, blue: 0.639, alpha: 1.0)

    // MARK: - Color tokens (Xcode Dark theme approximation)

    static let keywordColor = Color(red: 0.988, green: 0.373, blue: 0.639)    // #FC5FA3
    static let stringColor = Color(red: 0.988, green: 0.416, blue: 0.365)     // #FC6A5D
    static let commentColor = Color(red: 0.424, green: 0.475, blue: 0.525)    // #6C7986
    static let typeColor = Color(red: 0.816, green: 0.659, blue: 1.0)         // #D0A8FF
    static let numberColor = Color(red: 0.816, green: 0.749, blue: 0.412)     // #D0BF69
    static let defaultColor = Color(red: 0.878, green: 0.878, blue: 0.878)    // #E0E0E0

    // MARK: - Keywords

    private static let keywords: Set<String> = [
        "let", "var", "func", "class", "struct", "enum", "protocol", "extension",
        "import", "return", "if", "else", "guard", "while", "for", "in", "switch",
        "case", "default", "break", "continue", "fallthrough", "do", "try", "catch",
        "throw", "throws", "rethrows", "defer", "repeat", "where", "as", "is",
        "nil", "true", "false", "self", "Self", "super", "init", "deinit",
        "get", "set", "willSet", "didSet", "private", "fileprivate", "internal",
        "public", "open", "static", "final", "lazy", "weak", "unowned", "mutating",
        "nonmutating", "override", "convenience", "required", "typealias",
        "associatedtype", "inout", "some", "any", "async", "await", "actor",
        "isolated", "nonisolated", "Task", "@MainActor", "@Observable", "@State",
        "@Binding", "@Environment", "@Published",
    ]

    private static let typeNames: Set<String> = [
        "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
        "Double", "Float", "Bool", "String", "Character", "Array", "Dictionary", "Set",
        "Optional", "Result", "Error", "Void", "Any", "AnyObject",
        "URL", "URLSession", "URLRequest", "Data", "Date", "UUID", "TimeInterval",
        "View", "Text", "Button", "VStack", "HStack", "ZStack", "List", "ScrollView",
        "Image", "NavigationStack", "NavigationLink", "State", "Binding", "Environment",
        "ObservableObject", "ModelContainer", "ModelContext", "Query", "Model",
    ]

    // MARK: - Public API

    /// Highlights Swift source code as an AttributedString using Xcode-like colors.
    static func highlight(_ source: String) -> AttributedString {
        var attributed = AttributedString(source)
        // Base color for everything
        attributed.foregroundColor = defaultColor
        attributed.font = .system(.callout, design: .monospaced)

        let nsString = source as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        // Order matters: comments & strings first, then keywords/types/numbers.
        // Otherwise keywords inside strings would be miscolored.
        applyRegex(#"//[^\n]*"#, color: commentColor, in: &attributed, source: source, range: fullRange)
        applyRegex(#"/\*[\s\S]*?\*/"#, color: commentColor, in: &attributed, source: source, range: fullRange)
        applyRegex(#""(?:[^"\\]|\\.)*""#, color: stringColor, in: &attributed, source: source, range: fullRange)

        // Numbers (simple: integers and decimals)
        applyRegex(#"\b\d+(?:\.\d+)?\b"#, color: numberColor, in: &attributed, source: source, range: fullRange)

        // Keywords (word boundaries)
        for keyword in keywords {
            let escaped = NSRegularExpression.escapedPattern(for: keyword)
            let pattern = keyword.hasPrefix("@") ? escaped : "\\b\(escaped)\\b"
            applyRegex(pattern, color: keywordColor, in: &attributed, source: source, range: fullRange,
                       skipIfAlreadyColored: true)
        }

        // Type names
        for type in typeNames {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: type))\\b"
            applyRegex(pattern, color: typeColor, in: &attributed, source: source, range: fullRange,
                       skipIfAlreadyColored: true)
        }

        return attributed
    }

    // MARK: - Private

    private static func applyRegex(
        _ pattern: String,
        color: Color,
        in attributed: inout AttributedString,
        source: String,
        range: NSRange,
        skipIfAlreadyColored: Bool = false
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let matches = regex.matches(in: source, options: [], range: range)

        for match in matches {
            guard let stringRange = Range(match.range, in: source),
                  let attrRange = Range(stringRange, in: attributed) else { continue }

            if skipIfAlreadyColored {
                // Skip if this range is already inside a string/comment
                let existing = attributed[attrRange].foregroundColor
                if existing == stringColor || existing == commentColor {
                    continue
                }
            }

            attributed[attrRange].foregroundColor = color
        }
    }

    // MARK: - UIKit variant (for UITextView-based live editor)

    /// Returns an NSAttributedString with Xcode-like Swift syntax highlighting,
    /// for use in UITextView (where SwiftUI Color attributes don't apply).
    static func highlightForUIKit(_ source: String, fontSize: CGFloat = 16) -> NSAttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let ns = NSMutableAttributedString(string: source)
        let fullRange = NSRange(location: 0, length: (source as NSString).length)

        // Base attributes
        ns.addAttribute(.foregroundColor, value: uiDefaultColor, range: fullRange)
        ns.addAttribute(.font, value: font, range: fullRange)

        // Track which ranges are comments or strings (applied first, skipped by others)
        var protectedRanges: [NSRange] = []

        applyNSRegex(#"//[^\n]*"#, color: uiCommentColor, to: ns, source: source,
                     range: fullRange, tracking: &protectedRanges)
        applyNSRegex(#"/\*[\s\S]*?\*/"#, color: uiCommentColor, to: ns, source: source,
                     range: fullRange, tracking: &protectedRanges)
        applyNSRegex(#""(?:[^"\\]|\\.)*""#, color: uiStringColor, to: ns, source: source,
                     range: fullRange, tracking: &protectedRanges)

        applyNSRegex(#"\b\d+(?:\.\d+)?\b"#, color: uiNumberColor, to: ns, source: source,
                     range: fullRange, tracking: nil, protectedRanges: protectedRanges)

        // Keywords
        for keyword in keywords {
            let escaped = NSRegularExpression.escapedPattern(for: keyword)
            let pattern = keyword.hasPrefix("@") ? escaped : "\\b\(escaped)\\b"
            applyNSRegex(pattern, color: uiKeywordColor, to: ns, source: source,
                         range: fullRange, tracking: nil, protectedRanges: protectedRanges)
        }

        // Type names
        for type in typeNames {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: type))\\b"
            applyNSRegex(pattern, color: uiTypeColor, to: ns, source: source,
                         range: fullRange, tracking: nil, protectedRanges: protectedRanges)
        }

        return ns
    }

    private static func applyNSRegex(
        _ pattern: String,
        color: UIColor,
        to ns: NSMutableAttributedString,
        source: String,
        range: NSRange,
        tracking: UnsafeMutablePointer<[NSRange]>? = nil,
        protectedRanges: [NSRange] = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let matches = regex.matches(in: source, options: [], range: range)

        for match in matches {
            // Skip if this match is inside a protected range (comment/string)
            let isProtected = protectedRanges.contains { NSIntersectionRange($0, match.range).length > 0 }
            if isProtected { continue }

            ns.addAttribute(.foregroundColor, value: color, range: match.range)
            tracking?.pointee.append(match.range)
        }
    }
}
