import CoreLocation
import WeatherKit

/// 찍은 시각·장소의 실제 날씨(WeatherKit 지난 시간별 기록). 포털에서 WeatherKit 을 켜기 전엔 실패해 조용히 빈다.
enum WeatherLookup {
    static func weather(for m: Moment) async -> PlaceWeather? {
        guard let p = m.place else { return nil }
        let location = CLLocation(latitude: p.latitude, longitude: p.longitude)
        let start = m.capturedAt.addingTimeInterval(-3600), end = m.capturedAt.addingTimeInterval(3600)
        guard let hours = try? await WeatherService.shared.weather(for: location, including: .hourly(startDate: start, endDate: end)),
              let hour = hours.forecast.min(by: { abs($0.date.timeIntervalSince(m.capturedAt)) < abs($1.date.timeIntervalSince(m.capturedAt)) })
        else { return nil }
        return PlaceWeather(condition: hour.condition.rawValue, celsius: hour.temperature.converted(to: .celsius).value)
    }

    /// Apple 날씨 표기 — 날씨를 보여 주는 곳에 로고와 법적 고지 링크를 둬야 한다.
    static func attribution() async -> PhotoEnrichment.Attribution? {
        guard let a = try? await WeatherService.shared.attribution else { return nil }
        return .init(markURL: a.combinedMarkDarkURL, legalURL: a.legalPageURL)
    }
}
