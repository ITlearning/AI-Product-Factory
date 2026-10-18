import CoreLocation
import OSLog
import WeatherKit

/// WeatherKit 호출 — 앱(사진 날씨·지금 날씨·표기)과 위젯 확장(시간별 예보)이 같이 쓴다.
/// 확장에서 부르려면 위젯 App ID 에도 WeatherKit 능력이 켜져 있어야 한다(개발자 사이트).
public enum WeatherFeed {
    static let log = Logger(subsystem: "com.itlearning.colormoments", category: "weather")

    /// 시간별 기록·예보 — 실패하면 던진다(부르는 쪽이 캐시를 지킨다).
    public static func hourly(latitude: Double, longitude: Double, from start: Date, to end: Date) async throws -> [HourForecast] {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let hours = try await WeatherService.shared.weather(for: location, including: .hourly(startDate: start, endDate: end))
            return hours.forecast.map {
                HourForecast(date: $0.date, condition: $0.condition.rawValue, celsius: $0.temperature.converted(to: .celsius).value)
            }
        } catch {
            // 포털 WeatherKit 미반영·프로비저닝 프로필에 권한 없음이면 여기서 인증 오류가 난다.
            log.error("시간별 날씨 조회 실패 — \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    public static func current(latitude: Double, longitude: Double) async -> PlaceWeather? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let now = try await WeatherService.shared.weather(for: location, including: .current)
            return PlaceWeather(condition: now.condition.rawValue, celsius: now.temperature.converted(to: .celsius).value)
        } catch {
            log.error("지금 날씨 조회 실패 — \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Apple 날씨 표기 — 날씨를 보여 주는 곳에 로고와 법적 고지 링크를 둬야 한다.
    public static func attribution() async -> PhotoEnrichment.Attribution? {
        do {
            let a = try await WeatherService.shared.attribution
            return .init(markURL: a.combinedMarkDarkURL, legalURL: a.legalPageURL)
        } catch {
            log.error("날씨 표기 조회 실패 — \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// 시간 안에 못 끝나면 nil — 위젯은 시간 예산(약 5초) 안에 타임라인을 돌려줘야 한다.
    public static func within<T: Sendable>(_ seconds: Double, _ work: @escaping @Sendable () async -> T?) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await work() }
            group.addTask { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

/// 위젯 예보를 WeatherKit 에서 — 테스트는 다른 소스를 넣는다.
public struct WeatherKitForecast: ForecastSource {
    public init() {}
    public func hourly(latitude: Double, longitude: Double, from start: Date, to end: Date) async throws -> [HourForecast] {
        try await WeatherFeed.hourly(latitude: latitude, longitude: longitude, from: start, to: end)
    }
}
