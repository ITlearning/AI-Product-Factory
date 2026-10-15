import Foundation
import OSLog

/// 찍은 시각·장소의 실제 날씨(WeatherKit 지난 시간별 기록). 실패하면 빈 채로 두고 다음에 열 때 다시 찾는다.
/// WeatherKit 호출 자체는 위젯 확장과 같이 쓰는 WeatherFeed(Shared).
enum WeatherLookup {
    private static let log = Logger(subsystem: "com.itlearning.colormoments", category: "weather")

    static func weather(for m: Moment) async -> PlaceWeather? {
        guard let p = m.place else { return nil }
        let start = m.capturedAt.addingTimeInterval(-3600), end = m.capturedAt.addingTimeInterval(3600)
        guard let hours = try? await WeatherFeed.hourly(latitude: p.latitude, longitude: p.longitude, from: start, to: end)
        else { return nil }
        guard let hour = hours.min(by: { abs($0.date.timeIntervalSince(m.capturedAt)) < abs($1.date.timeIntervalSince(m.capturedAt)) })
        else {
            log.notice("날씨 기록 없음 — \(m.capturedAt, privacy: .public) 앞뒤 한 시간이 비었다")
            return nil
        }
        return hour.weather
    }

    /// 지금 날씨 — 「말」 칸의 지금 말. 5초 안에 못 받으면 nil(날씨 말 없이 고른다).
    static func now(at p: Place) async -> PlaceWeather? {
        let lat = p.latitude, lon = p.longitude
        return await WeatherFeed.within(5) { await WeatherFeed.current(latitude: lat, longitude: lon) }
    }

    static func attribution() async -> PhotoEnrichment.Attribution? {
        await WeatherFeed.attribution()
    }
}
