import Foundation

/// 홈 목록이 body 마다 다시 거르던 값 — 저장소가 바뀐 세대에 한 번만 만든다.
public struct HomeSummary: Equatable {

    public struct Row: Identifiable, Equatable {
        public let key: String
        public let index: Int
        public let month: String
        public let hasHeader: Bool
        public var id: String { key }
    }

    public let days: [String]
    public let giftedDays: [String]
    public let months: [String]
    public let handfulMonths: Set<String>
    public let lastYearDayKey: String?
    /// 목록 순서에서 그 달의 첫 하루.
    public let firstDayOfMonth: [String: String]
    public let rows: [Row]
    /// 진행 중 블록을 뺀 줄 id — 등장 연출 기준.
    public let appearanceIDs: [String]

    public static func make(days: [String], isGifted: (String) -> Bool, today: String) -> HomeSummary {
        let giftedDays = days.filter(isGifted)
        let handful = Set(Memories.months(giftedDays: giftedDays, today: today))
        var firstDayOfMonth: [String: String] = [:]
        var rows: [Row] = []
        var ids: [String] = []
        rows.reserveCapacity(days.count)
        ids.reserveCapacity(days.count + handful.count)
        for (index, key) in days.enumerated() {
            let month = String(key.prefix(7))
            let isMonthStart = firstDayOfMonth[month] == nil
            if isMonthStart { firstDayOfMonth[month] = key }
            let hasHeader = isMonthStart && handful.contains(month)
            if hasHeader { ids.append("month-\(month)") }
            ids.append(key)
            rows.append(Row(key: key, index: index, month: month, hasHeader: hasHeader))
        }
        return HomeSummary(days: days, giftedDays: giftedDays, months: HomeNavigation.months(of: days),
                           handfulMonths: handful,
                           lastYearDayKey: Memories.lastYear(today: today, giftedDays: giftedDays),
                           firstDayOfMonth: firstDayOfMonth, rows: rows, appearanceIDs: ids)
    }
}
