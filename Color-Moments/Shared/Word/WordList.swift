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

/// 단어가 주장하는 사실 — 확인되지 않으면 그 단어는 붙지 않는다.
public enum WordNeed: String, Codable, Sendable {
    /// 해가 비친다 — 맑은 날, 밤이 아닐 때.
    case sun
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
    /// 계절보다 좁은 때(무서리 10~11월). 비면 상관없다.
    public var months: [Int] = []
    public var needs: [WordNeed] = []
    /// 대상과 함께 사진에 있어야 하는 것 중 하나 — 사람만 찍힌 사진은 말벗이 아니다(밥상이 같이 있어야).
    public var with: [String] = []
    /// 기온을 말하는 단어 — 기온을 모르면 붙지 않는다.
    public var minCelsius: Double?
    public var maxCelsius: Double?
}

extension WordEntry {
    private enum CodingKeys: String, CodingKey {
        case id, word, meaning, times, weathers, seasons, subjects, moment, months, needs, with, minCelsius, maxCelsius
    }

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
        months = try c.decodeIfPresent([Int].self, forKey: .months) ?? []
        needs = try c.decodeIfPresent([WordNeed].self, forKey: .needs) ?? []
        with = try c.decodeIfPresent([String].self, forKey: .with) ?? []
        minCelsius = try c.decodeIfPresent(Double.self, forKey: .minCelsius)
        maxCelsius = try c.decodeIfPresent(Double.self, forKey: .maxCelsius)
    }
}

public struct WordList: Codable, Sendable {
    public let version: Int
    public let words: [WordEntry]
    /// 사진으로 확인할 수 없어 뺀 단어 — 이미 붙어 있으면 지우고 다시 고른다. 모르는 id(새 버전 단어)와 구분한다.
    public var retired: [String] = []

    private enum CodingKeys: String, CodingKey { case version, words, retired }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        words = try c.decode([WordEntry].self, forKey: .words)
        retired = try c.decodeIfPresent([String].self, forKey: .retired) ?? []
    }
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

    private static let list = load()
    /// 기록을 불러올 때 틀린 단어를 거르느라 동기로도 읽는다(DayStore).
    static let cached = list?.words ?? []
    static let retired = Set(list?.retired ?? [])

    public func words() async -> [WordEntry] { Self.cached }
}
