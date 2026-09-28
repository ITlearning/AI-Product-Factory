import Foundation

public struct LibrarySection: Equatable, Sendable {
    public let dayKey: String
    public let indices: [Int]
}

/// 사진을 최신순으로 조금씩 읽으며 섹션을 쌓는다 — 다 읽기 전에도 이미 다 모인 하루부터 보여 줄 수 있게.
public struct LibrarySectionBuilder: Sendable {
    private var order: [String] = []
    private var groups: [String: [Int]] = [:]
    private var lastKey: String?
    public private(set) var count = 0
    private let now: Date

    public init(now: Date = Date()) { self.now = now }

    public mutating func append(_ date: Date?) {
        let key = Moment.dayKey(for: date ?? now)
        if groups[key] == nil { order.append(key) }
        groups[key, default: []].append(count)
        count += 1
        lastKey = key
    }

    /// complete 가 아니면 마지막으로 읽던 하루는 아직 덜 모였을 수 있어 뺀다.
    public func sections(complete: Bool) -> [LibrarySection] {
        order.sorted(by: >).compactMap { key in
            guard complete || key != lastKey else { return nil }
            return LibrarySection(dayKey: key, indices: groups[key] ?? [])
        }
    }
}

public enum LibrarySections {

    public static func make(dates: [Date?], now: Date = Date()) -> [LibrarySection] {
        var builder = LibrarySectionBuilder(now: now)
        dates.forEach { builder.append($0) }
        return builder.sections(complete: true)
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
