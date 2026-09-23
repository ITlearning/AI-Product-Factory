import Foundation
import Observation

public enum GiftSchedule {

    public static func pending(dayKeys: [String], lastGifted: String?, today: String) -> String? {
        dayKeys.first { key in
            guard key < today else { return false }
            guard let lastGifted else { return true }
            return key > lastGifted
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
