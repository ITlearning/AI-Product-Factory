import Foundation

public struct PhotoContext: Equatable, Sendable {
    public let timeBand: TimeBand
    public let season: Season
    public let month: Int
    public let weather: Weather?
    public let celsius: Double?

    public init(date: Date, weather: Weather? = nil, celsius: Double? = nil, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.hour, .month], from: date)
        timeBand = Self.timeBand(hour: c.hour ?? 12)
        month = c.month ?? 1
        season = Self.season(month: month)
        self.weather = weather
        self.celsius = celsius
    }

    /// 실제 날씨(WeatherKit)가 먼저, 없으면 사진 속 하늘 짐작.
    public init(_ m: Moment, labels: [String], calendar: Calendar = .current) {
        let real = m.place?.weather
        self.init(date: m.capturedAt,
                  weather: real.flatMap { PhotoEnrichment.wordWeather($0.condition) } ?? Weather.inferred(from: Set(labels)),
                  celsius: real?.celsius, calendar: calendar)
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
