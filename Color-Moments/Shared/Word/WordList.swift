import Foundation

public enum TimeBand: String, Codable, Sendable, CaseIterable { case dawn, morning, noon, afternoon, dusk, night }
public enum Season: String, Codable, Sendable, CaseIterable { case spring, summer, autumn, winter }
public enum Weather: String, Codable, Sendable, CaseIterable { case clear, cloudy, rain, drizzle, snow, fog, wind }

public extension Weather {
    static func inferred(from labels: Set<String>) -> Weather? {
        if labels.contains("snow") { return .snow }
        if labels.contains("cloudy") { return .cloudy }
        if labels.contains("blue_sky") { return .clear }
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
