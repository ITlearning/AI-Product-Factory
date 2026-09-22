import Foundation
import Observation

/// 「하루가 끝나면 그날의 조약돌을 딱 한 번」을 정하는 규칙.
///
/// 이름은 «자정 증정»이지만 **실제로는 «자정이 지난 뒤 처음 앱을 열 때»** 증정된다.
/// v1 은 알림이 없으므로(설계 문서 v1 경계) 새벽 4시에 앱이 꺼져 있으면 그 순간에는
/// 띄울 방법이 없다. 그래서 «그 시각에 뜬다»가 아니라 «그 시각 이후 첫 만남에 뜬다»로 짓는다.
///
/// 순수 함수로 떼어낸 이유: 하루 경계·밀린 날 처리는 눈으로 확인하기 어려운 규칙이라
/// UI 없이 테스트로 못 박아야 한다.
public enum GiftSchedule {

    /// 지금 증정할 하루. 없으면 nil.
    ///
    /// - Parameters:
    ///   - dayKeys: 기록이 있는 날들. **최근 날짜부터** 정렬돼 있어야 한다(`DayStore.dayKeys`).
    ///   - lastGifted: 마지막으로 증정한 날. 첫 실행이면 nil.
    ///   - today: 오늘(새벽 4시 경계 기준)의 dayKey.
    ///
    /// 규칙 셋:
    /// 1. **오늘은 대상이 아니다.** 아직 안 끝난 하루를 증정하면 「자정에 열린다」가 깨진다.
    /// 2. **이미 증정한 날보다 뒤여야 한다.** 같은 하루를 두 번 주지 않는다.
    /// 3. **밀린 날이 여러 개면 가장 최근 하나만.** 사흘 만에 열었다고 세 번 연달아 보여주면
    ///    보상이 아니라 밀린 숙제가 된다. 나머지는 조용히 목록에 쌓인다 —
    ///    `markGifted` 가 가장 최근 날로 커서를 옮기므로 더 오래된 날은 다시 오지 않는다.
    public static func pending(dayKeys: [String], lastGifted: String?, today: String) -> String? {
        dayKeys.first { key in
            guard key < today else { return false }
            guard let lastGifted else { return true }
            return key > lastGifted
        }
    }
}

/// 증정 이력. 「하루에 한 번뿐」을 지키는 유일한 근거다.
///
/// 순간 기록(`DayStore`)과 섞지 않는다 — 저것은 «무엇을 담았나»이고 이것은 «무엇을 건넸나»라서
/// 지워지는 시점도 복구 방식도 다르다.
@Observable
public final class GiftLog {
    public private(set) var lastGiftedDayKey: String?

    private let defaults: UserDefaults
    private static let storageKey = "lastGiftedDayKey"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.lastGiftedDayKey = defaults.string(forKey: Self.storageKey)
    }

    /// 증정이 **끝난 뒤에** 부른다. 띄우는 순간이 아니라 닫는 순간에 남겨야,
    /// 보다가 앱이 죽어도 그 하루를 잃지 않는다.
    public func markGifted(_ dayKey: String) {
        lastGiftedDayKey = dayKey
        defaults.set(dayKey, forKey: Self.storageKey)
    }

    /// 기록을 전부 지울 때 같이 지운다. 안 그러면 커서만 미래에 남아 아무것도 증정되지 않는다.
    public func reset() {
        lastGiftedDayKey = nil
        defaults.removeObject(forKey: Self.storageKey)
    }
}
