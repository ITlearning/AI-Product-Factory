import Foundation

public enum OnboardingGift {

    /// 기록이 하나도 없던 상태에서 사진첩으로 여러 날을 한 번에 담았을 때, 오늘을 뺀 가장 최근
    /// 하루를 첫 증정 후보로 고른다 — 기존 기록이 있었거나 오늘만 담았으면 nil.
    public static func firstImportDay(existingRecordsWereEmpty: Bool, importedDayKeys: [String],
                                       today: String) -> String? {
        guard existingRecordsWereEmpty else { return nil }
        return importedDayKeys.filter { $0 != today }.max()
    }
}
