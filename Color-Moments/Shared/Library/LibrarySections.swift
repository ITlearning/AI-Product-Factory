import Foundation

public struct LibrarySection: Equatable, Sendable {
    public let dayKey: String
    public let indices: [Int]
}

public enum LibrarySections {

    public static func make(dates: [Date?], now: Date = Date()) -> [LibrarySection] {
        var order: [String] = []
        var groups: [String: [Int]] = [:]
        for (i, date) in dates.enumerated() {
            let key = Moment.dayKey(for: date ?? now)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(i)
        }
        return order.sorted(by: >).map { LibrarySection(dayKey: $0, indices: groups[$0] ?? []) }
    }

    public static func title(_ dayKey: String) -> String {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return dayKey }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        var c = DateComponents(); c.year = parts[0]; c.month = parts[1]; c.day = parts[2]; c.hour = 12
        guard let date = cal.date(from: c) else { return dayKey }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: date)
    }
}
