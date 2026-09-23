import Foundation
import Observation

public enum GiftSchedule {

    public static func pending(dayKeys: [String], lastGifted: String?, today: String,
                                hasSealedMoments: (String) -> Bool = { _ in true },
                                isFinished: ((String) -> Bool)? = nil) -> String? {
        // 기본값이 today 를 참조해야 해서 파라미터 기본값 대신 여기서 만든다.
        let isFinished = isFinished ?? { $0 < today }
        return dayKeys.first { key in
            guard isFinished(key) else { return false }
            if let lastGifted, key <= lastGifted { return false }
            return hasSealedMoments(key)
        }
    }
}

@Observable
public final class GiftLog {
    public private(set) var lastGiftedDayKey: String?

    private let defaults: UserDefaults
    private static let storageKey = "lastGiftedDayKey"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.lastGiftedDayKey = defaults.string(forKey: Self.storageKey)
    }

    public func markGifted(_ dayKey: String) {
        lastGiftedDayKey = dayKey
        defaults.set(dayKey, forKey: Self.storageKey)
    }

    public func reset() {
        lastGiftedDayKey = nil
        defaults.removeObject(forKey: Self.storageKey)
    }
}
