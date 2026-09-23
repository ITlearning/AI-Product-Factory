import Foundation

public struct Moment: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let capturedAt: Date

    public let colorHex: String

    public let fileName: String
    public let source: Source

    public enum Source: String, Codable, Sendable {

        case app

        case locked

        case library
    }

    public init(id: UUID = UUID(), capturedAt: Date, colorHex: String,
                fileName: String, source: Source) {
        self.id = id
        self.capturedAt = capturedAt
        self.colorHex = colorHex
        self.fileName = fileName
        self.source = source
    }
}

public extension Moment {

    var dayKey: String { Moment.dayKey(for: capturedAt) }

    static let dayBoundaryHour = 4

    static func dayKey(for date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let shifted = cal.date(byAdding: .hour, value: -dayBoundaryHour, to: date) ?? date
        let c = cal.dateComponents([.year, .month, .day], from: shifted)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
