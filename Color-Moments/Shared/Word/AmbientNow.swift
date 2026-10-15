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
    static func word(at date: Date, context ctx: PhotoContext,
                            in words: [WordEntry] = BundledWordSource.cached) -> WordEntry? {
        let pool = candidates(ctx, in: words)
        let plain = pool.filter { !$0.fallback }
        let use = plain.isEmpty ? pool : plain
        guard let top = use.map(rank).min() else { return nil }
        let front = use.filter { rank($0) == top }
        let most = front.map(WordPicker.specificity).max() ?? 0
        let seed = "\(ctx.dateKey)#\(ctx.hour)"
        return front.filter { WordPicker.specificity($0) == most }
            .min { (WordPicker.fnv1a(seed + ":" + $0.id), $0.id) < (WordPicker.fnv1a(seed + ":" + $1.id), $1.id) }
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
