import Foundation
import Observation

public enum GiftSchedule {

    public static func pending(dayKeys: [String], today: String, isGifted: (String) -> Bool,
                                hasSealedMoments: (String) -> Bool = { _ in true },
                                isFinished: ((String) -> Bool)? = nil) -> String? {
        // 기본값이 today 를 참조해야 해서 파라미터 기본값 대신 여기서 만든다.
        let isFinished = isFinished ?? { $0 < today }
        // 자연히 끝난 날은 가장 최근 하나만 후보(밀린 날을 줄줄이 증정하지 않는다), 그 다음 마무리한 오늘.
        if let natural = dayKeys.first(where: { $0 < today && hasSealedMoments($0) }), !isGifted(natural) { return natural }
        if dayKeys.contains(today), isFinished(today), hasSealedMoments(today), !isGifted(today) { return today }
        return nil
    }
}

@Observable
public final class GiftLog {
    public private(set) var giftedDayKeys: Set<String> = []
    private var legacyLast: String?

    /// 이 기기에서 실제로 바뀐 것만 — applyRemote 는 부르지 않는다(되돌아 올라가면 끝없이 돈다).
    @ObservationIgnored
    public var onLocalChange: ((String) -> Void)?

    private let defaults: UserDefaults
    private static let storageKey = "giftedDayKeys"
    private static let legacyStorageKey = "lastGiftedDayKey"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.giftedDayKeys = Set(defaults.stringArray(forKey: Self.storageKey) ?? [])
        self.legacyLast = defaults.string(forKey: Self.legacyStorageKey)
    }

    /// 새 집합에 있거나, 옛 단일값(lastGiftedDayKey) 이하 날짜면 이미 받은 것으로 본다 — 마이그레이션 없이 읽기 호환.
    public func isGifted(_ dayKey: String) -> Bool {
        giftedDayKeys.contains(dayKey) || (legacyLast.map { dayKey <= $0 } ?? false)
    }

    public func markGifted(_ dayKey: String) {
        guard !isGifted(dayKey) else { return }
        giftedDayKeys.insert(dayKey)
        defaults.set(Array(giftedDayKeys), forKey: Self.storageKey)
        onLocalChange?(dayKey)
    }

    /// 다른 기기에서 이미 받은 증정 — 여기서도 받았다고만 표시하고 알리지 않는다.
    public func applyRemote(gifted dayKey: String) {
        guard !isGifted(dayKey) else { return }
        giftedDayKeys.insert(dayKey)
        defaults.set(Array(giftedDayKeys), forKey: Self.storageKey)
    }

    public func reset() {
        giftedDayKeys = []
        legacyLast = nil
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.legacyStorageKey)
    }
}
