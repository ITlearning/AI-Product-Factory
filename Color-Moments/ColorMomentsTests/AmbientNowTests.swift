import XCTest
@testable import ColorMoments

final class AmbientNowTests: XCTestCase {

    private let words = BundledWordSource.cached

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        PhotoContext.korea.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// 한 해를 철마다 하루씩, 하루를 시간마다 — 날씨는 모름·맑음·비·가는 비·눈·안개.
    private var grid: [(Date, PlaceWeather?)] {
        let weathers: [PlaceWeather?] = [nil, .init(condition: "clear", celsius: 18), .init(condition: "rain", celsius: 14),
                                         .init(condition: "drizzle", celsius: 12), .init(condition: "snow", celsius: -2),
                                         .init(condition: "foggy", celsius: 9)]
        var out: [(Date, PlaceWeather?)] = []
        for m in [1, 4, 7, 10] {
            for h in 0..<24 { for w in weathers { out.append((date(2026, m, 15, h, 20), w)) } }
        }
        return out
    }

    func testOnlyMomentOrAmbientWordsEverComeOut() {
        var seen = 0
        for (d, w) in grid {
            guard let word = AmbientNow.word(at: d, context: AmbientNow.context(at: d, weather: w), in: words) else { continue }
            seen += 1
            XCTAssertTrue(word.moment || word.ambient, "\(word.word) 은 장면 말 — 위젯·지금의 말 후보가 아니다")
            XCTAssertFalse(word.rest)
        }
        XCTAssertGreaterThan(seen, grid.count / 2, "거의 늘 말 하나는 나와야 한다")
    }

    func testSceneWordsAreNotCandidates() throws {
        for w in words where !w.moment && !w.ambient {
            XCTAssertFalse(AmbientNow.isCandidate(w), w.word)
        }
        XCTAssertFalse(words.filter { !$0.moment && !$0.ambient }.isEmpty)
    }

    func testSameInputSameWord() {
        for (d, w) in grid.prefix(200) {
            let a = AmbientNow.word(at: d, context: AmbientNow.context(at: d, weather: w), in: words)
            let b = AmbientNow.word(at: d, context: AmbientNow.context(at: d, weather: w), in: words.reversed())
            XCTAssertEqual(a?.id, b?.id, "같은 날·같은 시각이면 목록 순서와 상관없이 같은 말")
        }
    }

    func testSameHourSameWordAcrossMinutes() {
        let a = date(2026, 10, 15, 18, 1), b = date(2026, 10, 15, 18, 2)
        XCTAssertEqual(AmbientNow.word(at: a, context: AmbientNow.context(at: a), in: words)?.id,
                       AmbientNow.word(at: b, context: AmbientNow.context(at: b), in: words)?.id)
    }

    func testNoLocationMeansSeoul() {
        for (d, w) in grid.prefix(300) {
            let none = AmbientNow.word(at: d, context: AmbientNow.context(at: d, weather: w), in: words)
            let seoul = AmbientNow.word(at: d, context: AmbientNow.context(at: d, weather: w, coordinate: Celestial.seoul), in: words)
            XCTAssertEqual(none?.id, seoul?.id)
        }
    }

    func testNoWeatherGivesComputedWordOnly() {
        var seen = 0
        for (d, w) in grid where w == nil {
            guard let word = AmbientNow.word(at: d, context: AmbientNow.context(at: d), in: words) else { continue }
            seen += 1
            XCTAssertTrue(word.weathers.isEmpty && word.conditions.isEmpty && word.needs.isEmpty, "\(word.word) — 날씨를 모르는데 날씨 말")
            XCTAssertNil(word.minCelsius, word.word)
            XCTAssertNil(word.maxCelsius, word.word)
        }
        XCTAssertGreaterThan(seen, 48)
    }

    func testRainComesBeforeTimeWords() throws {
        let d = date(2026, 10, 15, 18, 30)
        let word = try XCTUnwrap(AmbientNow.word(at: d, context: AmbientNow.context(at: d, weather: .init(condition: "rain", celsius: 14)),
                                                 in: words))
        XCTAssertEqual(AmbientNow.rank(word), 0, "\(word.word) — 비가 오면 비 말이 먼저")
        XCTAssertTrue(word.weathers.contains(.rain) || !word.conditions.isEmpty, word.word)
    }

    func testSceneKindFollowsConditions() throws {
        func kind(_ id: String) throws -> SceneKind { SceneKind.of(try XCTUnwrap(words.first { $0.id == id }, id)) }
        XCTAssertEqual(try kind("neungae"), .drizzle)
        XCTAssertEqual(try kind("jakdalbi"), .rain)
        XCTAssertEqual(try kind("nunbora"), .snow)
        XCTAssertEqual(try kind("haegeoreum"), .dusk)
        XCTAssertEqual(try kind("saebyeoknyeok"), .dawn)
        XCTAssertEqual(try kind("ondal"), .moon)
        XCTAssertEqual(try kind("gaeulbyeot"), .sun)
        XCTAssertEqual(try kind("kkotsaemchuwi"), .frost)
    }

    func testSceneFollowsTheHourOfTheSky() throws {
        let byeot = try XCTUnwrap(words.first { $0.id == "gaeulbyeot" })
        let rain = try XCTUnwrap(words.first { $0.id == "jakdalbi" })
        XCTAssertEqual(SceneKind.of(byeot, at: date(2026, 10, 15, 13)), .sun, "낮엔 말 그대로")
        XCTAssertEqual(SceneKind.of(byeot, at: date(2026, 10, 15, 23)), .stars, "밤엔 해 대신 별밤")
        XCTAssertEqual(SceneKind.of(byeot, at: date(2026, 10, 15, 23), cloudy: true), .moon, "흐린 밤은 달밤")
        XCTAssertEqual(SceneKind.of(byeot, at: date(2026, 10, 15, 6, 40)), .dawn, "해 뜰 녘 맑은 낮은 새벽")
        XCTAssertEqual(SceneKind.of(byeot, at: date(2026, 10, 15, 17, 50)), .dusk, "해 질 녘 맑은 낮은 노을")
        XCTAssertEqual(SceneKind.of(rain, at: date(2026, 10, 15, 23)), .rain, "비는 밤에도 비")
        XCTAssertEqual(SceneKind.leaves.at(date(2026, 10, 15, 2)), .stars)
        XCTAssertEqual(SceneKind.leaves.at(date(2026, 10, 15, 14)), .leaves)
    }

    func testNightSlotsNeverShowTheSun() {
        let night = AmbientNow.slots(from: date(2026, 10, 15, 21, 10), forecast: nil, place: nil, in: words)
        let day: Set<SceneKind> = [.sun, .petals, .leaves, .wind, .frost, .fog]
        for slot in night {
            let h = PhotoContext.korea.component(.hour, from: slot.date)
            guard h >= 20 || h < 5, let scene = slot.scene else { continue }
            XCTAssertFalse(day.contains(scene), "\(h)시 \(slot.word?.word ?? "")  → \(scene)")
        }
    }

    // MARK: 예보 캐시 — 3시간 재조회, 6시간 신선도, 실패하면 캐시 유지

    private struct FakeForecast: ForecastSource {
        var hours: [HourForecast] = []
        var fails = false
        var delay: Double = 0
        let calls = Counter()

        final class Counter: @unchecked Sendable { var n = 0 }

        func hourly(latitude: Double, longitude: Double, from start: Date, to end: Date) async throws -> [HourForecast] {
            calls.n += 1
            if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            if fails { throw URLError(.notConnectedToInternet) }
            return hours
        }
    }

    private func tempStore() -> AmbientStore {
        AmbientStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ambient-\(UUID())"))
    }

    private func hours(from start: Date, _ condition: String = "rain", celsius: Double = 14, count: Int = 26) -> [HourForecast] {
        (0..<count).map { HourForecast(date: start.addingTimeInterval(Double($0) * 3600), condition: condition, celsius: celsius) }
    }

    private let seoulPlace = SharedPlace(latitude: 37.5665, longitude: 126.978, at: Date())

    func testSharedPlaceIsCoarse() {
        let p = SharedPlace(latitude: 37.56789, longitude: 126.97812, at: Date())
        XCTAssertEqual(p.latitude, 37.57)
        XCTAssertEqual(p.longitude, 126.98)
    }

    func testForecastIsFreshForSixHoursOnly() {
        let fetched = date(2026, 10, 15, 9)
        let cache = ForecastCache(fetchedAt: fetched, latitude: 37.57, longitude: 126.98, hours: hours(from: fetched))
        XCTAssertEqual(cache.weather(at: fetched.addingTimeInterval(1800))?.condition, "rain")
        XCTAssertNotNil(cache.weather(at: fetched.addingTimeInterval(6 * 3600)), "엔트리 시각에서 6시간까지")
        XCTAssertNil(cache.weather(at: fetched.addingTimeInterval(6 * 3600 + 60)), "6시간 넘게 떨어지면 날씨 말을 빼야 한다")
        XCTAssertNil(cache.weather(at: fetched.addingTimeInterval(-3600)), "예보에 그 시간이 없으면 없다")
    }

    func testRefreshEveryThreeHoursAndWhenMoved() async throws {
        let store = tempStore()
        try store.save(place: seoulPlace)
        let t0 = date(2026, 10, 15, 9, 10)
        let source = FakeForecast(hours: hours(from: date(2026, 10, 15, 9)))
        let first = await AmbientNow.refresh(now: t0, store: store, source: source)
        XCTAssertEqual(first?.fetchedAt, t0)
        _ = await AmbientNow.refresh(now: t0.addingTimeInterval(2 * 3600), store: store, source: source)
        XCTAssertEqual(source.calls.n, 1, "3시간 안에는 다시 받지 않는다")
        let later = await AmbientNow.refresh(now: t0.addingTimeInterval(3 * 3600), store: store, source: source)
        XCTAssertEqual(source.calls.n, 2)
        XCTAssertEqual(later?.fetchedAt, t0.addingTimeInterval(3 * 3600))
        try store.save(place: SharedPlace(latitude: 35.18, longitude: 129.08, at: Date()))   // 부산
        _ = await AmbientNow.refresh(now: t0.addingTimeInterval(3 * 3600 + 60), store: store, source: source)
        XCTAssertEqual(source.calls.n, 3, "50km 넘게 옮기면 바로 다시 받는다")
    }

    func testFailureOrTimeoutKeepsCache() async throws {
        let store = tempStore()
        try store.save(place: seoulPlace)
        let t0 = date(2026, 10, 15, 9, 10)
        let cached = ForecastCache(fetchedAt: t0, latitude: seoulPlace.latitude, longitude: seoulPlace.longitude,
                                   hours: hours(from: date(2026, 10, 15, 9)))
        try store.save(forecast: cached)
        let failed = await AmbientNow.refresh(now: t0.addingTimeInterval(4 * 3600), store: store, source: FakeForecast(fails: true))
        XCTAssertEqual(failed, cached, "실패하면 캐시를 그대로")
        XCTAssertEqual(store.forecast(), cached)
        let slow = await AmbientNow.refresh(now: t0.addingTimeInterval(4 * 3600), store: store,
                                            source: FakeForecast(hours: hours(from: t0, "snow"), delay: 2), timeout: 0.2)
        XCTAssertEqual(slow, cached, "시간 예산을 넘기면 기다리지 않고 캐시")
        XCTAssertEqual(store.forecast(), cached)
        try store.save(place: SharedPlace(latitude: 35.18, longitude: 129.08, at: Date()))
        let moved = await AmbientNow.refresh(now: t0.addingTimeInterval(4 * 3600), store: store, source: FakeForecast(fails: true))
        XCTAssertNil(moved, "옮긴 뒤 못 받았으면 옛 자리 예보는 쓰지 않는다")
        XCTAssertEqual(store.forecast(), cached, "지우지는 않는다")
    }

    func testNoPlaceMeansNoWeatherWords() async throws {
        let store = tempStore()
        let t0 = date(2026, 10, 15, 9, 10)
        let source = FakeForecast(hours: hours(from: date(2026, 10, 15, 9)))
        let none = await AmbientNow.refresh(now: t0, store: store, source: source)
        XCTAssertNil(none)
        XCTAssertEqual(source.calls.n, 0, "위치가 없으면 묻지도 않는다")
        let rainy = ForecastCache(fetchedAt: t0, latitude: 37.57, longitude: 126.98, hours: hours(from: date(2026, 10, 15, 0), count: 48))
        for slot in AmbientNow.slots(from: t0, forecast: rainy, place: nil, in: words) {
            XCTAssertFalse(slot.knewWeather)
            if let w = slot.word {
                XCTAssertTrue(w.weathers.isEmpty && w.conditions.isEmpty && w.needs.isEmpty && w.minCelsius == nil && w.maxCelsius == nil,
                              "\(w.word) — 위치가 없는데 날씨 말")
            }
        }
    }

    func testStaleForecastFallsBackToComputedWords() {
        let t0 = date(2026, 10, 15, 9, 10)
        let old = ForecastCache(fetchedAt: t0.addingTimeInterval(-7 * 3600), latitude: seoulPlace.latitude,
                                longitude: seoulPlace.longitude, hours: hours(from: date(2026, 10, 14, 0), count: 72))
        for slot in AmbientNow.slots(from: t0, forecast: old, place: seoulPlace, in: words) {
            XCTAssertFalse(slot.knewWeather, "7시간 넘은 예보")
            if let w = slot.word { XCTAssertNotEqual(AmbientNow.rank(w), 0, w.word) }
        }
        let fresh = ForecastCache(fetchedAt: t0, latitude: seoulPlace.latitude, longitude: seoulPlace.longitude,
                                  hours: hours(from: date(2026, 10, 15, 9)))
        let slots = AmbientNow.slots(from: t0, forecast: fresh, place: seoulPlace, in: words)
        XCTAssertTrue(slots[0].knewWeather)
        XCTAssertFalse(slots[23].knewWeather, "받은 지 6시간이 넘는 칸은 계산형")
        XCTAssertEqual(slots[0].word.map(AmbientNow.rank), 0, "비가 오면 첫 칸은 비 말")
    }

    // MARK: 하루 24칸 (R4)

    private func weathers(_ condition: String?) -> (Date) -> PlaceWeather? {
        { _ in condition.map { PlaceWeather(condition: $0, celsius: 14) } }
    }

    func testDayWordsAreDeterministic() {
        for m in [1, 4, 7, 10] {
            for c in [nil, "rain", "clear", "snow"] {
                let day = date(2026, m, 15, 0)
                let a = AmbientNow.dayWords(on: day, weather: weathers(c), coordinate: nil, in: words).map { $0?.id }
                let b = AmbientNow.dayWords(on: day.addingTimeInterval(5 * 3600), weather: weathers(c), coordinate: nil,
                                            in: words.reversed()).map { $0?.id }
                XCTAssertEqual(a, b, "같은 날·같은 날씨면 언제 다시 만들어도, 목록 순서와 상관없이 같은 24칸")
                XCTAssertEqual(a.count, 24)
            }
        }
    }

    func testNoRepeatNextToEachOtherAndFewRepeatsInADay() {
        let pool = words.filter(AmbientNow.isCandidate)
        for m in 1...12 {
            for c in [nil, "rain", "clear", "drizzle", "snow", "foggy"] {
                let day = date(2026, m, 8, 0)
                let picks = AmbientNow.dayWords(on: day, weather: weathers(c), coordinate: nil, in: words)
                var shown = Set<String>()
                for h in 0..<24 {
                    let at = AmbientNow.hourMiddle(day, h, PhotoContext.korea)
                    let options = AmbientNow.ordered(AmbientNow.context(at: at, weather: weathers(c)(at)), in: pool).map(\.id)
                    guard let id = picks[h]?.id else { XCTAssertTrue(options.isEmpty); continue }
                    if h > 0, options.count >= 2 { XCTAssertNotEqual(id, picks[h - 1]?.id, "\(m)월 \(c ?? "-") \(h)시 — 앞 칸과 같은 말") }
                    if shown.contains(id) {
                        XCTAssertTrue(options.allSatisfy { shown.contains($0) || $0 == picks[h - 1]?.id },
                                      "\(m)월 \(c ?? "-") \(h)시 — 안 뜬 후보가 남았는데 다시 뜬 말")
                    }
                    shown.insert(id)
                }
            }
        }
    }

    func testSlotsAgreeAcrossRebuilds() {
        let morning = date(2026, 10, 15, 10, 5), noon = date(2026, 10, 15, 13, 40)
        let a = AmbientNow.slots(from: morning, forecast: nil, place: nil, in: words)
        let b = AmbientNow.slots(from: noon, forecast: nil, place: nil, in: words)
        XCTAssertEqual(a.count, 24)
        XCTAssertEqual(a[0].date, morning, "첫 칸은 지금")
        XCTAssertEqual(a[1].date, date(2026, 10, 15, 11), "다음 칸부터 정시")
        let byHour = Dictionary(uniqueKeysWithValues: a.dropFirst().map { ($0.date, $0.word?.id) })
        for slot in b.dropFirst() where byHour[slot.date] != nil {
            XCTAssertEqual(slot.word?.id, byHour[slot.date] ?? nil, "3시간 뒤 다시 만들어도 같은 시각엔 같은 말")
        }
        XCTAssertNotEqual(Set(a.map { PhotoContext.korea.component(.day, from: $0.date) }).count, 1, "24칸이면 자정을 넘는다")
    }

    func testSlotsNeverShowSceneWords() {
        for m in [2, 5, 8, 11] {
            for slot in AmbientNow.slots(from: date(2026, m, 3, 7, 30), forecast: nil, place: seoulPlace, in: words) {
                guard let w = slot.word else { continue }
                XCTAssertTrue(AmbientNow.isCandidate(w), "\(w.word) — 장면 말")
                XCTAssertTrue(w.subjects.isEmpty, w.word)
                XCTAssertEqual(slot.scene, SceneKind.of(w, at: slot.date, coordinate: seoulPlace.coordinate), "말 장면을 그 시각 하늘에 맞춘 것")
            }
        }
    }
}

