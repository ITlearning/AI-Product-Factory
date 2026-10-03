import Foundation

public struct PhotoContext: Equatable, Sendable {
    public let timeBand: TimeBand
    public let season: Season
    public let month: Int
    public let hour: Int
    public let weather: Weather?
    /// WeatherKit 원래 이름(heavyRain·flurries…) — 일곱 갈래 날씨로 뭉개기 전.
    public let condition: String?
    public let celsius: Double?
    public let sunAltitude: Double
    /// 해 높이를 실제 찍은 자리로 계산했나(아니면 서울로 본 값).
    public let placeKnown: Bool
    public let moonAge: Double

    public init(date: Date, weather: Weather? = nil, celsius: Double? = nil, condition: String? = nil,
                coordinate: (latitude: Double, longitude: Double)? = nil, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.hour, .month], from: date)
        hour = c.hour ?? 12
        timeBand = Self.timeBand(hour: hour)
        month = c.month ?? 1
        season = Self.season(month: month)
        self.weather = weather
        self.condition = condition
        self.celsius = celsius
        let at = coordinate ?? Celestial.seoul
        sunAltitude = Celestial.sunAltitude(at: date, latitude: at.latitude, longitude: at.longitude)
        placeKnown = coordinate != nil
        moonAge = Celestial.moonAge(at: date)
    }

    /// 실제 날씨(WeatherKit)가 먼저, 없으면 사진 속 하늘 짐작.
    public init(_ m: Moment, labels: [String], calendar: Calendar = .current) {
        let real = m.place?.weather
        self.init(date: m.capturedAt,
                  weather: real.flatMap { PhotoEnrichment.wordWeather($0.condition) } ?? Weather.inferred(from: Set(labels)),
                  celsius: real?.celsius, condition: real?.condition,
                  coordinate: m.place.map { ($0.latitude, $0.longitude) }, calendar: calendar)
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
