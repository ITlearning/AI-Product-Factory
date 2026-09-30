import CoreLocation
import OSLog
import WeatherKit

/// 찍은 시각·장소의 실제 날씨(WeatherKit 지난 시간별 기록). 실패하면 빈 채로 두고 다음에 열 때 다시 찾는다.
enum WeatherLookup {
    private static let log = Logger(subsystem: "com.itlearning.colormoments", category: "weather")

    static func weather(for m: Moment) async -> PlaceWeather? {
        guard let p = m.place else { return nil }
        let location = CLLocation(latitude: p.latitude, longitude: p.longitude)
        let start = m.capturedAt.addingTimeInterval(-3600), end = m.capturedAt.addingTimeInterval(3600)
        do {
            let hours = try await WeatherService.shared.weather(for: location, including: .hourly(startDate: start, endDate: end))
            guard let hour = hours.forecast.min(by: { abs($0.date.timeIntervalSince(m.capturedAt)) < abs($1.date.timeIntervalSince(m.capturedAt)) })
            else {
                log.notice("날씨 기록 없음 — \(m.capturedAt, privacy: .public) 앞뒤 한 시간이 비었다")
                return nil
            }
            return PlaceWeather(condition: hour.condition.rawValue, celsius: hour.temperature.converted(to: .celsius).value)
        } catch {
            // 포털 WeatherKit 미반영·프로비저닝 프로필에 권한 없음이면 여기서 인증 오류가 난다.
            log.error("날씨 조회 실패 — \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Apple 날씨 표기 — 날씨를 보여 주는 곳에 로고와 법적 고지 링크를 둬야 한다.
    static func attribution() async -> PhotoEnrichment.Attribution? {
        do {
            let a = try await WeatherService.shared.attribution
            return .init(markURL: a.combinedMarkDarkURL, legalURL: a.legalPageURL)
        } catch {
            log.error("날씨 표기 조회 실패 — \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
