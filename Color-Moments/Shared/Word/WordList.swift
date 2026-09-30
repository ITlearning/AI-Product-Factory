import Foundation

public enum TimeBand: String, Codable, Sendable, CaseIterable { case dawn, morning, noon, afternoon, dusk, night }
public enum Season: String, Codable, Sendable, CaseIterable { case spring, summer, autumn, winter }
public enum Weather: String, Codable, Sendable, CaseIterable { case clear, cloudy, rain, drizzle, snow, fog, wind }

public extension Weather {
    static func inferred(from labels: Set<String>) -> Weather? {
        if labels.contains("snow") { return .snow }
        if labels.contains("blue_sky") { return .clear }
        if labels.contains("cloudy") { return .cloudy }
        return nil
    }
}

public struct WordEntry: Codable, Equatable, Sendable {
    public let id: String
    public let word: String
    public let meaning: String
    public let times: [TimeBand]
    public let weathers: [Weather]
    public let seasons: [Season]
    public let subjects: [String]
    /// 사진에 뭐가 찍혔든 그 「때」(시간대·날씨·계절)만 말하는 단어 — 맞는 대상이 없을 때 쓴다(WordPicker).
    public var moment: Bool = false
}

extension WordEntry {
    private enum CodingKeys: String, CodingKey { case id, word, meaning, times, weathers, seasons, subjects, moment }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        word = try c.decode(String.self, forKey: .word)
        meaning = try c.decode(String.self, forKey: .meaning)
        times = try c.decode([TimeBand].self, forKey: .times)
        weathers = try c.decode([Weather].self, forKey: .weathers)
        seasons = try c.decode([Season].self, forKey: .seasons)
        subjects = try c.decode([String].self, forKey: .subjects)
        moment = try c.decodeIfPresent(Bool.self, forKey: .moment) ?? false
    }
}

public struct WordList: Codable, Sendable {
    public let version: Int
    public let words: [WordEntry]
}

public protocol WordSource: Sendable {
    func words() async -> [WordEntry]
}

public struct BundledWordSource: WordSource {
    public init() {}

    public static func load() -> WordList? {
        let bundle = Bundle(for: SharedBundleMarker.self)
        guard let url = bundle.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WordList.self, from: data)
    }

    private static let cached = load()?.words ?? []

    public func words() async -> [WordEntry] { Self.cached }
}
