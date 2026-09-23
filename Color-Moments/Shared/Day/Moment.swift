import Foundation

public struct Place: Codable, Equatable, Sendable {
    public let latitude, longitude, accuracy: Double
    public var name: String?

    public init(latitude: Double, longitude: Double, accuracy: Double, name: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.name = name
    }
}

public struct Moment: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let capturedAt: Date

    public let colorHex: String

    public let fileName: String
    public let source: Source
    public var word: PhotoWord?
    public var labels: [String]?
    public var assetID: String?
    public var place: Place?
    public var addedAt: Date?
    public var batchID: UUID?

    public enum Source: String, Codable, Sendable {

        case app

        case locked

        case library
    }

    public init(id: UUID = UUID(), capturedAt: Date, colorHex: String,
                fileName: String, source: Source, word: PhotoWord? = nil, labels: [String]? = nil,
                assetID: String? = nil, place: Place? = nil, addedAt: Date? = nil, batchID: UUID? = nil) {
        self.id = id
        self.capturedAt = capturedAt
        self.colorHex = colorHex
        self.fileName = fileName
        self.source = source
        self.word = word
        self.labels = labels
        self.assetID = assetID
        self.place = place
        self.addedAt = addedAt
        self.batchID = batchID
    }
}

public extension Moment {

    var dayKey: String { Moment.dayKey(for: capturedAt) }

    static let dayBoundaryHour = 4

    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()

    static func dayKey(for date: Date) -> String {
        let shifted = calendar.date(byAdding: .hour, value: -dayBoundaryHour, to: date) ?? date
        let c = calendar.dateComponents([.year, .month, .day], from: shifted)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func sealDate(for dayKey: String) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents(); c.year = parts[0]; c.month = parts[1]; c.day = parts[2]; c.hour = dayBoundaryHour
        guard let start = calendar.date(from: c) else { return nil }
        return calendar.date(byAdding: .day, value: 1, to: start)
    }
}
