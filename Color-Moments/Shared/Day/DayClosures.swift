import Foundation
import Observation

/// 오늘을 「마무리하기」로 일찍 닫은 시각을 하루 단위로 기억한다.
@Observable
public final class DayClosures {
    public private(set) var closedDays: [String: Date] = [:]

    private let defaults: UserDefaults
    private static let storageKey = "dayClosures"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.dictionary(forKey: Self.storageKey) as? [String: Double] ?? [:]
        closedDays = stored.mapValues { Date(timeIntervalSince1970: $0) }
    }

    public func closedAt(_ dayKey: String) -> Date? { closedDays[dayKey] }

    public func close(_ dayKey: String, at date: Date = Date()) {
        // 이미 닫힌 날을 다시 닫으면 닫힌 시각이 늦춰져 나중 사진이 조약돌에 섞일 수 있다.
        guard closedDays[dayKey] == nil else { return }
        closedDays[dayKey] = date
        persist()
    }

    public func reset() {
        closedDays = [:]
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        defaults.set(closedDays.mapValues { $0.timeIntervalSince1970 }, forKey: Self.storageKey)
    }
}
