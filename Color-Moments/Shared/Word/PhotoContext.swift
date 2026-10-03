import Foundation

public struct PhotoContext: Equatable, Sendable {
    public let timeBand: TimeBand
    public let season: Season
    public let month: Int
    public let hour: Int
    public let weekday: Int
    public let weather: Weather?
    /// WeatherKit 원래 이름(heavyRain·flurries…) — 일곱 갈래 날씨로 뭉개기 전.
    public let condition: String?
    public let celsius: Double?
    public let sunAltitude: Double
    public let moonAge: Double

    public init(date: Date, weather: Weather? = nil, celsius: Double? = nil, condition: String? = nil,
                coordinate: (latitude: Double, longitude: Double)? = nil, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.hour, .month, .weekday], from: date)
        hour = c.hour ?? 12
        weekday = c.weekday ?? 1
        timeBand = Self.timeBand(hour: hour)
        month = c.month ?? 1
        season = Self.season(month: month)
        self.weather = weather
        self.condition = condition
        self.celsius = celsius
        let at = coordinate ?? Celestial.seoul
        sunAltitude = Celestial.sunAltitude(at: date, latitude: at.latitude, longitude: at.longitude)
        moonAge = Celestial.moonAge(at: date)
    }

    /// 단어의 시각·달·요일은 한국 시간으로 본다 — 보는 기기의 시간대로 보면 해외에 있는 기기가 같은 사진에 다른 판정을 내려
    /// iCloud 로 서로의 단어를 지운다(2026-10-03 교차 검증: 파리 기기와 사진 5.7%). 몽돌은 한국 앱이다.
    public static let korea: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    /// 한국 밖에서 찍은 사진(자리가 있을 때)은 경도로 잡은 현지 시각 — 파리 오후 두 시 사진에 「여름밤」이 붙지 않게.
    /// 경도 15° 가 한 시간이라 유럽·중국 서부는 한두 시간 어긋날 수 있다. 어느 기기에서 봐도 같은 값이라 단어가 갈리지 않는다.
    public static func calendar(for m: Moment) -> Calendar {
        guard let p = m.place, !((33...39.5).contains(p.latitude) && (124...132).contains(p.longitude)) else { return korea }
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: Int((p.longitude / 15).rounded()) * 3600) ?? korea.timeZone
        return c
    }

    /// 실제 날씨(WeatherKit)가 먼저, 없으면 사진 속 하늘 짐작.
    public init(_ m: Moment, labels: [String], calendar: Calendar? = nil) {
        let calendar = calendar ?? Self.calendar(for: m)
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
