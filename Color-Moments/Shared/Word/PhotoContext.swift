import Foundation

public struct PhotoContext: Equatable, Sendable {
    public let timeBand: TimeBand
    public let season: Season
    public let weather: Weather?

    public init(date: Date, weather: Weather? = nil, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.hour, .month], from: date)
        timeBand = Self.timeBand(hour: c.hour ?? 12)
        season = Self.season(month: c.month ?? 1)
        self.weather = weather
    }

    public static func timeBand(hour: Int) -> TimeBand {
        switch hour {
        case 4..<7: .dawn
        case 7..<11: .morning
        case 11..<15: .noon
        case 15..<17: .afternoon
        case 17..<20: .dusk
        default: .night
        }
    }

    public static func season(month: Int) -> Season {
        switch month {
        case 3...5: .spring
        case 6...8: .summer
        case 9...11: .autumn
        default: .winter
        }
    }
}
