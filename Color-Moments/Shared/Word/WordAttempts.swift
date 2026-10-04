import Foundation

/// 사진별 학생 실패 횟수 — 이 기기에만(UserDefaults). 세 번이면 규칙 단어.
public final class WordAttempts: @unchecked Sendable {
    public static let shared = WordAttempts()
    public static let limit = 3
    private let defaults: UserDefaults
    private let key = "wordModelFailures"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private var all: [String: Int] {
        get { defaults.dictionary(forKey: key) as? [String: Int] ?? [:] }
        set { defaults.set(newValue, forKey: key) }
    }
    public func failures(_ id: UUID) -> Int { all[id.uuidString] ?? 0 }
    public func fail(_ id: UUID) { all[id.uuidString, default: 0] += 1 }
    public func clear(_ id: UUID) { all[id.uuidString] = nil }
}
