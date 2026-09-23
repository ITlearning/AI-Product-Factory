import Foundation
import Observation

/// 오늘을 「마무리하기」로 일찍 닫은 시각을 하루 단위로 기억한다.
@Observable
public final class DayClosures {
    public private(set) var closedDays: [String: Date] = [:]

    /// 이 기기에서 실제로 바뀐 것만 — applyRemote 는 부르지 않는다(되돌아 올라가면 끝없이 돈다).
    /// 구독 전에 생긴 변경은 모아 두었다가 설정되는 순간 넘긴다.
    @ObservationIgnored
    public var onLocalChange: ((String) -> Void)? {
        didSet {
            guard let onLocalChange else { return }
            let keys = unsent
            unsent = []
            keys.forEach(onLocalChange)
        }
    }
    @ObservationIgnored private var unsent: [String] = []

    private func notify(_ dayKey: String) {
        guard let onLocalChange else { unsent.append(dayKey); return }
        onLocalChange(dayKey)
    }

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
        notify(dayKey)
    }

    /// 다른 기기에서 온 마무리 — 이른 쪽을 남기고, 여기서도 알리지 않는다(되돌아 올라가면 끝없이 돈다).
    public func applyRemote(dayKey: String, closedAt: Date) {
        if let mine = closedDays[dayKey], mine <= closedAt { return }
        closedDays[dayKey] = closedAt
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
