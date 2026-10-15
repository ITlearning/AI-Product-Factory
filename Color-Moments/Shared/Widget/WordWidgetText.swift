import Foundation

/// 위젯 문구 — 소스 대신 widget-words.json 에 둔다. 확장 글꼴(고운돋움 Mini)은 이 파일의 글자로 굽는다.
public struct WordWidgetText: Codable, Equatable, Sendable {

    public struct Scene: Codable, Equatable, Sendable {
        public let lines: [String]
        public let short: String
    }

    public let brand: String
    public let name: String
    public let description: String
    public let lockDescription: String
    public let pick: String
    public let picked: String
    public let pickHint: String
    public let scene: String
    /// SceneStyle 이름 — 위젯 편집의 모양 고르기.
    public let looks: [String: String]
    public let scenes: [String: Scene]

    static func load(bundle: Bundle = Bundle(for: SharedBundleMarker.self)) -> WordWidgetText? {
        guard let url = bundle.url(forResource: "widget-words", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WordWidgetText.self, from: data)
    }

    public static let cached = load()

    /// 말 앞뒤로 나눈 장면 문장 — 말만 명조로 그린다.
    public struct Sentence: Equatable, Sendable {
        public let before: String
        public let word: String
        public let after: String
        public var plain: String { before + word + after }
    }

    /// 말마다 틀 하나 — 같은 말이면 늘 같은 문장.
    public func sentence(_ word: String, id: String, scene kind: SceneKind) -> Sentence? {
        guard let lines = scenes[kind.rawValue]?.lines, !lines.isEmpty else { return nil }
        let line = lines[Int(WordPicker.fnv1a(id) % UInt64(lines.count))]
        return Self.fill(line, word: word)
    }

    public func short(_ word: String, scene kind: SceneKind) -> String {
        scenes[kind.rawValue].flatMap { Self.fill($0.short, word: word)?.plain } ?? word
    }

    public func sceneLabel(_ kind: SceneKind) -> String {
        scene.replacingOccurrences(of: "{s}", with: kind.name)
    }

    static let wordMark = "{w}"

    /// 틀의 {이/가}·{은/는}·{을/를}·{과/와}·{으로/로} 를 말의 받침으로 고른다.
    static func fill(_ template: String, word: String) -> Sentence? {
        guard let r = template.range(of: wordMark) else { return nil }
        return Sentence(before: String(template[..<r.lowerBound]), word: word,
                        after: particles(String(template[r.upperBound...]), after: word))
    }

    static func particles(_ text: String, after word: String) -> String {
        var out = ""
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            out += rest[..<open]
            let pair = rest[rest.index(after: open)..<close].split(separator: "/").map(String.init)
            out += pair.count == 2 ? particle(pair[0], pair[1], after: word) : String(rest[open...close])
            rest = rest[rest.index(after: close)...]
        }
        return out + rest
    }

    /// 받침 있으면 앞, 없으면 뒤. 으로/로 는 ㄹ 받침이면 로.
    static func particle(_ withFinal: String, _ withoutFinal: String, after word: String) -> String {
        guard let last = word.unicodeScalars.last, (0xAC00...0xD7A3).contains(last.value) else { return withoutFinal }
        let final = (last.value - 0xAC00) % 28
        if final == 0 { return withoutFinal }
        if withoutFinal == "\u{B85C}", final == 8 { return withoutFinal }
        return withFinal
    }
}
