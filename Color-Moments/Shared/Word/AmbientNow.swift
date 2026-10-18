import Foundation

/// 「지금 밖에 맞는 말」 — 「말」 칸 빈 상태와 위젯이 같이 쓴다. 판정은 사진 단어와 같은 WordPicker.judge.
/// 같은 입력이면 같은 말(씨앗 = 그날 0시 기준 날짜 + 시각, R4).
public enum AmbientNow {

    /// R1 후보 — 사진 없이 때·날씨만으로 맞는 말. 장면 말(찔레꽃·자리끼)은 moment·ambient 가 아니라 여기서 빠진다.
    public static func isCandidate(_ w: WordEntry) -> Bool { (w.moment || w.ambient) && !w.rest }

    /// 날씨를 모르면(.unknown) 날씨 말은 빠진다 — 시각·해·달·철로만 맞는 계산형 말이 남는다.
    public static func candidates(_ ctx: PhotoContext, in words: [WordEntry]) -> [WordEntry] {
        words.filter { isCandidate($0) && WordPicker.judge($0, ctx) == .yes }
    }

    /// 앞 갈래만 남긴다(날씨 > 기온 > 달 > 해·시각 > 철), 그 안에선 조건이 많은 말, 그래도 여럿이면 씨앗.
    /// 그 한 시각만 본다 — 하루 안 반복 피하기는 dayWords.
    static func word(at date: Date, context ctx: PhotoContext,
                            in words: [WordEntry] = BundledWordSource.cached) -> WordEntry? {
        ordered(ctx, in: words).first
    }

    /// 그 시각에 맞는 후보 전부를 고르는 순서대로 — 갈래, 좁은 조건, 씨앗(dayKey + 시각).
    static func ordered(_ ctx: PhotoContext, in words: [WordEntry]) -> [WordEntry] {
        let pool = candidates(ctx, in: words)
        let plain = pool.filter { !$0.fallback }
        let use = plain.isEmpty ? pool : plain
        let seed = "\(ctx.dateKey)#\(ctx.hour)"
        return use.map { (w: $0, rank: rank($0), spec: -WordPicker.specificity($0), hash: WordPicker.fnv1a(seed + ":" + $0.id)) }
            .sorted { ($0.rank, $0.spec, $0.hash, $0.w.id) < ($1.rank, $1.spec, $1.hash, $1.w.id) }
            .map(\.w)
    }

    // MARK: 하루 24칸 (R4) — 저장 없이 그날 0시부터 다시 계산한다

    /// 그날(0시 기준) 한 시간마다의 말 — 앞 칸과 같은 말은 피하고, 그날 이미 뜬 말은 후보가 남는 한 피한다.
    /// 같은 날·같은 날씨면 언제 다시 만들어도 같은 24칸.
    static func dayWords(on day: Date, weather: (Date) -> PlaceWeather?,
                         coordinate: (latitude: Double, longitude: Double)?,
                         in words: [WordEntry], calendar: Calendar = PhotoContext.korea) -> [WordEntry?] {
        let pool = words.filter(isCandidate)
        let start = calendar.startOfDay(for: day)
        var shown = Set<String>()
        var previous: String?
        var out: [WordEntry?] = []
        for hour in 0..<24 {
            let at = hourMiddle(start, hour, calendar)
            let ctx = context(at: at, weather: weather(at), coordinate: coordinate, calendar: calendar)
            let list = ordered(ctx, in: pool)
            let pick = list.first { $0.id != previous && !shown.contains($0.id) }
                ?? list.first { $0.id != previous } ?? list.first
            if let pick { shown.insert(pick.id) }
            previous = pick?.id
            out.append(pick)
        }
        return out
    }

    /// 한 시간 칸의 대표 시각 — 몇 분에 다시 만들어도 같은 해 높이·같은 말.
    static func hourMiddle(_ dayStart: Date, _ hour: Int, _ calendar: Calendar) -> Date {
        (calendar.date(byAdding: .hour, value: hour, to: dayStart) ?? dayStart).addingTimeInterval(1800)
    }

    /// 위젯 한 칸.
    public struct Slot: Equatable, Sendable {
        public let date: Date
        public let word: WordEntry?
        public let scene: SceneKind?
        public let moonAge: Double
        /// 그 칸을 고를 때 날씨를 알았는지 — 모르면 계산형 말.
        public let knewWeather: Bool
    }

    /// now 부터 한 시간 단위 count 칸 — 첫 칸은 now, 다음 칸부터 정시. 위치가 없으면 서울 해 높이에 날씨 말 없음.
    static func slots(from now: Date, count: Int = 24, forecast: ForecastCache?, place: SharedPlace?,
                      in words: [WordEntry] = BundledWordSource.cached,
                      calendar: Calendar = PhotoContext.korea) -> [Slot] {
        let usable = place.flatMap { p in forecast.flatMap { $0.isNear(p) ? $0 : nil } }
        let weather: (Date) -> PlaceWeather? = { usable?.weather(at: $0) }
        let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        var days: [Date: [WordEntry?]] = [:]
        return (0..<count).map { i in
            let date = i == 0 ? now : hourStart.addingTimeInterval(Double(i) * 3600)
            let dayStart = calendar.startOfDay(for: date)
            let hour = calendar.component(.hour, from: date)
            if days[dayStart] == nil {
                days[dayStart] = dayWords(on: dayStart, weather: weather, coordinate: place?.coordinate, in: words, calendar: calendar)
            }
            let list = days[dayStart] ?? []
            let word = list.indices.contains(hour) ? list[hour] : nil
            let middle = hourMiddle(dayStart, hour, calendar)
            let cloudy = weather(middle).flatMap { PhotoEnrichment.wordWeather($0.condition) } == .cloudy
            return Slot(date: date, word: word,
                        scene: word.map { SceneKind.of($0, at: date, coordinate: place?.coordinate, cloudy: cloudy) },
                        moonAge: Celestial.moonAge(at: middle), knewWeather: weather(middle) != nil)
        }
    }

    static func rank(_ w: WordEntry) -> Int {
        if !w.weathers.isEmpty || !w.conditions.isEmpty || !w.needs.isEmpty { return 0 }
        if w.minCelsius != nil || w.maxCelsius != nil { return 1 }
        if !w.moonAges.isEmpty { return 2 }
        if !w.times.isEmpty || !w.hours.isEmpty || w.sunMin != nil || w.sunMax != nil { return 3 }
        return 4
    }

    /// 앱이 가진 지금 날씨·위치로 — 위치가 없으면 서울 해 높이, 날씨가 없으면 날씨 말 없음.
    public static func context(at date: Date, weather: PlaceWeather? = nil,
                               coordinate: (latitude: Double, longitude: Double)? = nil,
                               calendar: Calendar = PhotoContext.korea) -> PhotoContext {
        PhotoContext(date: date, weather: weather.flatMap { PhotoEnrichment.wordWeather($0.condition) },
                     celsius: weather?.celsius, condition: weather?.condition,
                     coordinate: coordinate, calendar: calendar)
    }
}

// MARK: - 장면 갈래 — 말 데이터의 조건에서 유도한다

public extension SceneKind {

    /// 말의 장면을 그 시각 하늘에 맞춘다 — 밤엔 낮 장면 대신 밤하늘, 해 뜰·질 녘 맑은 낮은 새벽·노을. 비·눈은 밤에도 그대로.
    static func of(_ w: WordEntry, at date: Date, coordinate: (latitude: Double, longitude: Double)? = nil,
                   cloudy: Bool = false, calendar: Calendar = PhotoContext.korea) -> SceneKind {
        of(w).at(date, coordinate: coordinate, cloudy: cloudy, calendar: calendar)
    }

    func at(_ date: Date, coordinate: (latitude: Double, longitude: Double)? = nil, cloudy: Bool = false,
            calendar: Calendar = PhotoContext.korea) -> SceneKind {
        switch self {
        case .rain, .drizzle, .snow, .moon, .stars: return self
        default: break
        }
        let at = coordinate ?? Celestial.seoul
        let sun = Celestial.sunAltitude(at: date, latitude: at.latitude, longitude: at.longitude)
        if sun < -6 { return cloudy || self == .fog ? .moon : .stars }
        if sun < 6, self == .sun { return calendar.component(.hour, from: date) < 12 ? .dawn : .dusk }
        return self
    }

    static func of(_ w: WordEntry) -> SceneKind {
        if let fall = fromConditions(w.conditions) { return fall }
        for weather in w.weathers {
            switch weather {
            case .snow: return .snow
            case .rain: return .rain
            case .drizzle: return .drizzle
            case .fog: return .fog
            case .wind: return .wind
            case .clear, .cloudy: continue
            }
        }
        if !w.moonAges.isEmpty { return .moon }
        if let sky = fromSky(w) { return sky }
        if let max = w.maxCelsius, max <= 5 { return .frost }
        if let min = w.minCelsius, min >= 25 { return .sun }
        if w.weathers.contains(.clear) || w.needs.contains(.sun) { return .sun }
        if let season = w.seasons.first ?? w.months.first.map(PhotoContext.season(month:)) { return of(season) }
        return .sun
    }

    static func of(_ season: Season) -> SceneKind {
        switch season {
        case .spring: .petals
        case .summer: .sun
        case .autumn: .leaves
        case .winter: .frost
        }
    }

    /// 카드 오른쪽 아래·VoiceOver 에 쓰는 이름.
    var name: String {
        switch self {
        case .sun: "맑은 낮"
        case .dawn: "새벽"
        case .dusk: "노을"
        case .stars: "밤하늘"
        case .moon: "달"
        case .rain: "비"
        case .drizzle: "가는 비"
        case .snow: "눈"
        case .fog: "안개"
        case .wind: "바람"
        case .petals: "꽃잎"
        case .leaves: "낙엽"
        case .frost: "서리"
        }
    }

    private static func fromConditions(_ conditions: [String]) -> SceneKind? {
        let snow: Set = ["snow", "flurries", "heavySnow", "blizzard", "blowingSnow", "sunFlurries", "sleet", "wintryMix"]
        let drizzle: Set = ["drizzle", "freezingDrizzle"]
        let fog: Set = ["foggy", "haze", "smoky", "blowingDust"]
        let wind: Set = ["windy", "breezy"]
        for c in conditions {
            if snow.contains(c) { return .snow }
            if drizzle.contains(c) { return .drizzle }
            if fog.contains(c) { return .fog }
            if wind.contains(c) { return .wind }
            if c.lowercased().contains("rain") || c.lowercased().contains("storm") || c == "sunShowers" { return .rain }
        }
        return nil
    }

    private static func fromSky(_ w: WordEntry) -> SceneKind? {
        let hours = w.hours.isEmpty ? nil : w.hours
        if let max = w.sunMax, max <= 10, (w.sunMin ?? -90) >= -14 {
            let morning = hours.map { $0.allSatisfy { $0 < 12 } } ?? w.times.contains(.dawn)
            return morning ? .dawn : .dusk
        }
        if let max = w.sunMax, max < -14 { return .stars }
        let bands = !w.times.isEmpty ? w.times : (hours?.map(PhotoContext.timeBand(hour:)) ?? [])
        guard !bands.isEmpty else { return w.sunMin.map { $0 > 10 ? .sun : nil } ?? nil }
        let counts = Dictionary(bands.map { ($0, 1) }, uniquingKeysWith: +)
        let main = TimeBand.allCases.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) } ?? .noon
        switch main {
        case .dawn: return .dawn
        case .dusk: return .dusk
        case .night: return .stars
        case .morning, .noon, .afternoon: return .sun
        }
    }
}
