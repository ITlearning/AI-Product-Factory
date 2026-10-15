import Foundation

/// 시간별 예보 한 칸 — 위젯이 App Group 에 두고 쓴다.
public struct HourForecast: Codable, Equatable, Sendable {
    public let date: Date
    /// WeatherKit WeatherCondition.rawValue
    public let condition: String
    public let celsius: Double

    public init(date: Date, condition: String, celsius: Double) {
        self.date = date
        self.condition = condition
        self.celsius = celsius
    }

    public var weather: PlaceWeather { PlaceWeather(condition: condition, celsius: celsius) }
}

public protocol ForecastSource: Sendable {
    func hourly(latitude: Double, longitude: Double, from start: Date, to end: Date) async throws -> [HourForecast]
}

/// 앱이 마지막으로 얻은 위치 — 소수 2자리(약 1km)로 깎아 App Group 에만 둔다. 기기 밖으로 나가지 않는다.
public struct SharedPlace: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let at: Date

    public init(latitude: Double, longitude: Double, at: Date) {
        self.latitude = Self.coarse(latitude)
        self.longitude = Self.coarse(longitude)
        self.at = at
    }

    static func coarse(_ v: Double) -> Double { (v * 100).rounded() / 100 }

    public var coordinate: (latitude: Double, longitude: Double) { (latitude, longitude) }

    public func kilometers(toLatitude lat: Double, longitude lon: Double) -> Double {
        let r = 6371.0, rad = Double.pi / 180
        let dLat = (lat - latitude) * rad, dLon = (lon - longitude) * rad
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(latitude * rad) * cos(lat * rad) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }
}

/// 받아 둔 예보 — 3시간 지나면 다시 받고, 엔트리 시각에서 6시간 넘게 떨어진 예보는 쓰지 않는다(Open Question 3: 첫 값).
public struct ForecastCache: Codable, Equatable, Sendable {
    public static let refetchAfter: TimeInterval = 3 * 3600
    public static let freshFor: TimeInterval = 6 * 3600
    public static let moveKilometers = 50.0

    public let fetchedAt: Date
    public let latitude: Double
    public let longitude: Double
    public let hours: [HourForecast]

    public init(fetchedAt: Date, latitude: Double, longitude: Double, hours: [HourForecast]) {
        self.fetchedAt = fetchedAt
        self.latitude = latitude
        self.longitude = longitude
        self.hours = hours.sorted { $0.date < $1.date }
    }

    /// 그 시각이 든 한 시간 칸의 날씨 — 예보가 낡았거나 그 시간이 없으면 nil(계산형 말로 물러난다).
    public func weather(at date: Date) -> PlaceWeather? {
        guard abs(date.timeIntervalSince(fetchedAt)) <= Self.freshFor else { return nil }
        return hours.last { $0.date <= date && date < $0.date.addingTimeInterval(3600) }?.weather
    }

    public func isNear(_ place: SharedPlace) -> Bool {
        place.kilometers(toLatitude: latitude, longitude: longitude) <= Self.moveKilometers
    }

    public func needsRefetch(now: Date, place: SharedPlace) -> Bool {
        now.timeIntervalSince(fetchedAt) >= Self.refetchAfter || now < fetchedAt || !isNear(place)
    }
}

/// App Group 안 두 파일 — 예보(위젯·앱이 덮어씀)와 마지막 위치(앱만 씀).
public struct AmbientStore: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    public init?() {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)
        else { return nil }
        self.init(directory: dir)
    }

    var forecastURL: URL { directory.appendingPathComponent("ambient-forecast.json") }
    var placeURL: URL { directory.appendingPathComponent("ambient-place.json") }

    public func place() -> SharedPlace? { read(placeURL) }
    public func forecast() -> ForecastCache? { read(forecastURL) }

    public func save(place: SharedPlace) throws { try write(place, to: placeURL) }
    public func save(forecast: ForecastCache) throws { try write(forecast, to: forecastURL) }

    /// 위치를 끄거나 거절했을 때 — 위젯은 날씨 말을 쓰지 않는다.
    public func clear() {
        try? FileManager.default.removeItem(at: placeURL)
        try? FileManager.default.removeItem(at: forecastURL)
    }

    private func read<T: Decodable>(_ url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}

public extension AmbientNow {

    /// 예보가 3시간보다 낡았거나 50km 넘게 옮겼으면 다시 받는다. 실패·시간 초과면 캐시를 그대로 둔다.
    /// 위치가 없으면 nil — 날씨 말을 쓰지 않는다. 옮긴 뒤 못 받았으면 옛 자리 예보도 쓰지 않는다.
    static func refresh(now: Date = Date(), store: AmbientStore, source: ForecastSource,
                        timeout: Double = 5, calendar: Calendar = PhotoContext.korea) async -> ForecastCache? {
        guard let place = store.place() else { return nil }
        let cached = store.forecast()
        if let cached, !cached.needsRefetch(now: now, place: place) { return cached }
        let start = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let end = start.addingTimeInterval(26 * 3600)
        let hours = await WeatherFeed.within(timeout) {
            try? await source.hourly(latitude: place.latitude, longitude: place.longitude, from: start, to: end)
        }
        guard let hours, !hours.isEmpty else { return cached.flatMap { $0.isNear(place) ? $0 : nil } }
        let fresh = ForecastCache(fetchedAt: now, latitude: place.latitude, longitude: place.longitude, hours: hours)
        try? store.save(forecast: fresh)
        return fresh
    }
}
