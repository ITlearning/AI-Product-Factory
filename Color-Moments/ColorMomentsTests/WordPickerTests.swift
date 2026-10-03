import XCTest
@testable import ColorMoments

final class WordPickerTests: XCTestCase {

    private func w(_ id: String, times: [TimeBand] = [], weathers: [Weather] = [], seasons: [Season] = [],
                   subjects: [String] = ["sky"]) -> WordEntry {
        WordEntry(id: id, word: id, meaning: "뜻 \(id)", times: times, weathers: weathers, seasons: seasons, subjects: subjects)
    }

    private let utc: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    private let kst: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Seoul")!; return c }()
    private func seoul(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, weather: Weather? = nil, celsius: Double? = nil,
                       condition: String? = nil) -> PhotoContext {
        var c = DateComponents(); c.year = 2026; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return PhotoContext(date: kst.date(from: c)!, weather: weather, celsius: celsius, condition: condition,
                            coordinate: Celestial.seoul, calendar: kst)
    }
    private var dusk: PhotoContext { PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), calendar: utc) } // 1970-01-01 18:00 → dusk, winter
    private func pick(_ ctx: PhotoContext, _ labels: [String], _ words: [WordEntry], recent: Set<String> = []) -> [String] {
        WordPicker.candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: "s").map(\.id)
    }

    func testFixtureIsDuskWinter() { XCTAssertEqual(dusk.timeBand, .dusk); XCTAssertEqual(dusk.season, .winter) }

    func testOnlyWordsWhoseSubjectIsInThePhoto() {
        let words = [w("sea", subjects: ["ocean"]), w("desk", subjects: ["laptop"]), w("idle", subjects: [])]
        XCTAssertEqual(pick(dusk, ["ocean", "sky"], words), ["sea"])
    }

    func testNothingInThePhotoFallsBackToTheMoment() {
        let words = [w("sea", subjects: ["ocean"]), w("duskword", times: [.dusk], subjects: []).asMoment,
                     w("moonhalo", times: [.dusk], subjects: ["moon"])]
        XCTAssertEqual(pick(dusk, ["laptop"], words), ["duskword"], "맞는 대상이 없으면 그 때의 말로 — 비워 두지 않는다")
        XCTAssertEqual(pick(dusk, [], words), ["duskword"])
    }

    func testMomentFallbackPrefersRealWeatherThenTimeThenSeason() {
        let rainy = PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), weather: .rain, calendar: utc)
        let words = [w("rainword", weathers: [.rain], subjects: []).asMoment,
                     w("duskword", times: [.dusk], subjects: []).asMoment,
                     w("winterword", seasons: [.winter], subjects: []).asMoment]
        XCTAssertEqual(pick(rainy, ["laptop"], words).first, "rainword")
        XCTAssertEqual(pick(dusk, ["laptop"], words).first, "duskword", "날씨를 모르면 비 말은 안 쓴다")
        XCTAssertEqual(pick(dusk, ["laptop"], [words[2]]), ["winterword"])
        XCTAssertEqual(pick(dusk, ["laptop"], [w("dawnword", times: [.dawn], subjects: []).asMoment]), [],
                       "때의 말도 시간대는 풀지 않는다")
    }

    func testBannedWordNeverComesBack() {
        let words = [w("sea", subjects: ["ocean"]), w("shore", subjects: ["ocean"]),
                     w("duskword", times: [.dusk], subjects: []).asMoment]
        XCTAssertEqual(pick(dusk, ["ocean"], words, recent: ["shore"]).first, "sea")
        XCTAssertEqual(WordPicker.candidates(for: dusk, labels: ["ocean"], in: words, excluding: [], seed: "s", banned: ["sea"]).map(\.id),
                       ["shore"], "버린 단어는 최근 단어처럼 풀리지 않는다")
        XCTAssertEqual(WordPicker.candidates(for: dusk, labels: ["ocean"], in: words, excluding: [], seed: "s",
                                             banned: ["sea", "shore"]).map(\.id), ["duskword"], "다 버리면 그 때의 말로")
    }

    func testModelChoicesAddSafeMomentWords() {
        let words = [w("heat", times: [.dusk], subjects: ["land"]), w("duskword", times: [.dusk], subjects: []).asMoment,
                     w("moonhalo", times: [.dusk], subjects: ["moon"])]
        XCTAssertEqual(WordPicker.choices(for: dusk, labels: ["land"], in: words, excluding: [], seed: "s").map(\.id),
                       ["heat", "duskword"], "규칙 후보가 하나여도 모델이 고를 여지 — 대상 없는 달무리는 안 들어간다")
    }

    func testMomentFallbackNeverUsesSubjectWords() {
        XCTAssertEqual(pick(dusk, ["laptop"], [w("moonhalo", times: [.dusk], subjects: ["moon"])]), [],
                       "대상을 말하는 단어는 대상이 찍혔을 때만")
    }

    /// 실제 단어 목록으로 — 사진에서 아무것도 못 알아봐도 어느 시각·계절·날씨든 단어가 붙는다.
    func testBundledWordsAlwaysGiveAWord() async throws {
        let words = await BundledWordSource().words()
        XCTAssertFalse(words.isEmpty)
        let weathers: [Weather?] = [nil] + Weather.allCases
        for hour in 0..<24 {
            for month in 1...12 {
                var c = DateComponents(); c.year = 2026; c.month = month; c.day = 15; c.hour = hour
                let date = kst.date(from: c)!
                for weather in weathers {
                    let ctx = PhotoContext(date: date, weather: weather, calendar: kst)
                    let word = WordPicker.photoWord(for: ctx, labels: [], in: words, excluding: [], seed: "\(hour)-\(month)")
                    XCTAssertNotNil(word, "\(hour)시 \(month)월 \(weather.map(\.rawValue) ?? "날씨 모름")에 단어가 없다")
                    if let word { XCTAssertTrue(words.first { $0.id == word.wordID }?.moment == true, word.word) }
                }
            }
        }
    }

    func testTimeBandIsNeverRelaxed() {
        let words = [w("dawnword", times: [.dawn])]
        XCTAssertEqual(pick(dusk, ["sky"], words), [], "해질녘 하늘에 새벽 말이 붙으면 안 된다")
    }

    func testSeasonIsNeverRelaxed() {
        XCTAssertEqual(pick(dusk, ["sky"], [w("summerword", seasons: [.summer])]), [], "계절이 붙은 단어는 계절이 곧 뜻 — 10월의 아지랑이")
    }

    func testWeatherlessPhotoSkipsWeatherWords() {
        let words = [w("rainy", weathers: [.rain]), w("plain")]
        XCTAssertEqual(pick(dusk, ["sky"], words), ["plain"])
        XCTAssertEqual(pick(dusk, ["sky"], [w("rainy", weathers: [.rain])]), [], "날씨를 모르면 날씨 말은 끝까지 안 쓴다")
    }

    func testKnownWeatherNeverGetsOtherWeatherWords() {
        let snowy = PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), weather: .snow, calendar: utc)
        XCTAssertEqual(pick(snowy, ["snow"], [w("snowword", weathers: [.snow], subjects: ["snow"])]), ["snowword"])

        let words = [w("p", weathers: [.rain], seasons: [.winter]), w("q", weathers: [.fog], seasons: [.summer])]
        XCTAssertEqual(pick(snowy, ["sky"], words), [], "다른 날씨 말은 끝까지 안 쓴다")

        let clear = PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), weather: .clear, calendar: utc)
        XCTAssertEqual(pick(clear, ["sky"], [w("a", weathers: [.clear]), w("r", weathers: [.rain])], recent: ["a"]), ["a"],
                       "최근 반복을 허용할지언정 비 말은 안 쓴다")

        XCTAssertEqual(pick(clear, ["sky"], [w("s", seasons: [.summer])]), [], "계절은 풀지 않는다")
    }

    func testSubjectInFrontWins() {
        let words = [w("skyword", subjects: ["sky"]), w("seaword", subjects: ["ocean"]), w("meal", subjects: ["food"]),
                     w("desk", subjects: ["computer"])]
        XCTAssertEqual(pick(dusk, ["outdoor", "blue_sky", "sky", "ocean"], words).first, "seaword", "하늘은 대상 뒤")
        XCTAssertEqual(pick(dusk, ["food", "computer"], words).first, "meal", "먼저 잡힌 대상이 주인공")
        XCTAssertEqual(pick(dusk, ["computer", "food"], words).first, "desk")
        XCTAssertEqual(pick(dusk, ["outdoor", "sky"], words), ["skyword"], "하늘뿐이면 하늘 단어")
    }

    func testWithNeedsOneMoreThingInThePhoto() {
        var friend = w("friend", subjects: ["people"]); friend.with = ["food", "drink"]
        XCTAssertEqual(pick(dusk, ["people", "eyeglasses"], [friend]), [], "사람만 찍힌 사진")
        XCTAssertEqual(pick(dusk, ["people", "tableware", "food"], [friend]), ["friend"])
    }

    func testSpecificLabelBeatsItsBroadParent() {
        let words = [w("greenery", subjects: ["plant"]), w("wildflower", subjects: ["daffodil"])]
        XCTAssertEqual(pick(dusk, ["plant", "daffodil", "flower"], words).first, "wildflower", "Vision 은 plant 를 daffodil 앞에 둔다")
    }

    func testBroadLabelFarBackIsNoEvidence() {
        let words = [w("greenery", subjects: ["plant"]), w("skyword", subjects: ["sky"]),
                     w("duskword", times: [.dusk], subjects: []).asMoment]
        XCTAssertEqual(pick(dusk, ["outdoor", "sky", "blue_sky", "cord", "plant"], words).first, "skyword",
                       "하늘 사진 귀퉁이의 풀은 근거가 못 된다")
        XCTAssertEqual(pick(dusk, ["outdoor", "blue_sky", "plant"], [words[0], words[2]]), ["greenery"], "앞쪽에 잡힌 풀은 근거")
        let dawnSky = w("dawnsky", times: [.dawn], subjects: ["sky", "blue_sky"])
        XCTAssertEqual(pick(dusk, ["outdoor", "sky", "blue_sky", "cord", "plant"], [words[0], dawnSky, words[2]]), ["duskword"],
                       "하늘 단어가 때가 안 맞아도 풀 한 포기로 넘어가지 않는다")
    }

    func testSunWordsNeedClearDaylight() {
        var shimmer = w("shimmer", subjects: ["water"]); shimmer.needs = [.sun]
        func at(_ hour: Int, _ weather: Weather?) -> PhotoContext {
            PhotoContext(date: Date(timeIntervalSince1970: Double(hour) * 3600), weather: weather, coordinate: (0, 0), calendar: utc)
        }
        XCTAssertEqual(pick(at(12, .clear), ["water"], [shimmer]), ["shimmer"])
        XCTAssertEqual(pick(at(12, .cloudy), ["water"], [shimmer]), [], "흐린 날 물에 윤슬은 거짓말")
        XCTAssertEqual(pick(at(12, nil), ["water"], [shimmer]), [], "날씨를 모르면 해도 모른다")
        XCTAssertEqual(pick(at(23, .clear), ["water"], [shimmer]), [], "맑아도 밤엔 해가 없다")
    }

    func testMonthsAreNarrowerThanSeasons() {
        var frost = w("frost"); frost.months = [10, 11]
        var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 20; c.hour = 7
        let september = PhotoContext(date: utc.date(from: c)!, calendar: utc)
        c.month = 10
        let october = PhotoContext(date: utc.date(from: c)!, calendar: utc)
        XCTAssertEqual(september.season, october.season)
        XCTAssertEqual(pick(september, ["sky"], [frost]), [])
        XCTAssertEqual(pick(october, ["sky"], [frost]), ["frost"])
    }

    func testTemperatureWordsNeedAKnownTemperature() {
        var chill = w("chill"); chill.maxCelsius = 5
        func ctx(_ c: Double?) -> PhotoContext {
            PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600), weather: .clear, celsius: c, calendar: utc)
        }
        XCTAssertEqual(pick(ctx(3), ["sky"], [chill]), ["chill"])
        XCTAssertEqual(pick(ctx(8), ["sky"], [chill]), [])
        XCTAssertEqual(pick(ctx(nil), ["sky"], [chill]), [], "기온을 모르면 추위를 말하지 않는다")
    }

    func testOnlyKnownFactsContradictAStampedWord() {
        func ctx(_ hour: Int, _ weather: Weather?, _ celsius: Double? = nil) -> PhotoContext {
            PhotoContext(date: Date(timeIntervalSince1970: Double(hour) * 3600), weather: weather, celsius: celsius,
                         coordinate: (0, 0), calendar: utc)
        }
        var shimmer = w("shimmer", subjects: ["water"]); shimmer.needs = [.sun]
        var frost = w("frost", subjects: ["grass"]); frost.maxCelsius = 5
        let words = [w("foxrain", weathers: [.rain], subjects: ["blue_sky"]), w("spring", seasons: [.spring]), shimmer, frost,
                     w("desk", subjects: ["desk"])]
        func contradicted(_ id: String, _ c: PhotoContext) -> Bool {
            WordPicker.contradicted(PhotoWord(wordID: id, word: id, meaning: ""), context: c, in: words, retired: ["moonhalo"])
        }
        XCTAssertTrue(contradicted("foxrain", ctx(15, .clear)), "비 안 온 맑은 날의 여우비")
        XCTAssertTrue(contradicted("spring", ctx(15, .clear)), "1월의 봄 단어")
        XCTAssertTrue(contradicted("shimmer", ctx(15, .cloudy)))
        XCTAssertFalse(contradicted("shimmer", ctx(15, nil)), "날씨를 모르면 뒤집지 못한다")
        XCTAssertTrue(contradicted("frost", ctx(7, .clear, 12)))
        XCTAssertFalse(contradicted("frost", ctx(7, .clear)), "기온을 모르면 뒤집지 못한다")
        XCTAssertFalse(contradicted("desk", ctx(15, .clear)), "대상이 덜 맞는 정도로는 지우지 않는다")
        XCTAssertTrue(contradicted("moonhalo", ctx(23, .clear)), "사진으로 확인할 수 없어 뺀 단어")
        XCTAssertFalse(contradicted("fromnewerversion", ctx(15, .clear)), "모르는 id 는 새 버전 단어 — 지우면 다른 기기 단어를 덮는다")
    }

    func testShownWordHidesOnlyContradictedOrRetiredWords() {
        let place = Place(latitude: 37.5, longitude: 127, accuracy: 10, weather: PlaceWeather(condition: "clear", celsius: 20))
        let words = [w("foxrain", weathers: [.rain], subjects: ["blue_sky"]), w("sky", subjects: ["sky"])]
        func moment(_ id: String, labels: [String]?) -> Moment {
            Moment(capturedAt: Date(timeIntervalSince1970: 15 * 3600), colorHex: "#888888", fileName: "x.jpg", source: .app,
                   word: PhotoWord(wordID: id, word: id, meaning: ""), labels: labels, place: place)
        }
        XCTAssertNil(moment("foxrain", labels: ["blue_sky", "sky"]).standingWord(in: words, retired: []))
        XCTAssertNil(moment("sky", labels: ["sky"]).standingWord(in: words, retired: ["sky"]), "뺀 단어")
        XCTAssertEqual(moment("sky", labels: ["sky"]).standingWord(in: words, retired: [])?.wordID, "sky")
        XCTAssertEqual(moment("fromnewer", labels: ["sky"]).standingWord(in: words, retired: [])?.wordID, "fromnewer",
                       "모르는 id 는 새 버전 단어 — 가리지 않는다")
        XCTAssertEqual(moment("foxrain", labels: ["sky"]).standingWord(in: [], retired: [])?.wordID, "foxrain",
                       "목록을 못 읽었으면 가리지 않는다")
    }

    func testPhotosAbroadUseLocalClockFromLongitude() {
        var c = DateComponents(); c.year = 2026; c.month = 7; c.day = 15; c.hour = 12   // UTC 12시 = 파리 오후, 서울 밤 9시
        c.timeZone = TimeZone(identifier: "UTC")
        let at = Calendar(identifier: .gregorian).date(from: c)!
        let paris = Moment(capturedAt: at, colorHex: "#888888", fileName: "p.jpg", source: .app,
                           place: Place(latitude: 48.86, longitude: 2.35, accuracy: 10))
        let seoul = Moment(capturedAt: at, colorHex: "#888888", fileName: "s.jpg", source: .app,
                           place: Place(latitude: 37.57, longitude: 126.98, accuracy: 10))
        XCTAssertEqual(PhotoContext(paris, labels: []).timeBand, .noon, "파리 한낮에 「여름밤」이 붙으면 안 된다")
        XCTAssertEqual(PhotoContext(seoul, labels: []).hour, 21)
    }

    /// Tabber 기기 사진에서 틀렸던 자리 — 실제 단어 목록으로(2026-10-03 실측을 본뜬 사례, 실제 기록은 넣지 않는다).
    func testBundledWordsNoLongerSayTheseFalseThings() async throws {
        let words = await BundledWordSource().words()
        func word(_ month: Int, _ hour: Int, _ weather: Weather?, _ celsius: Double?, _ labels: [String]) -> String? {
            let ctx = seoul(month, 2, hour, weather: weather, celsius: celsius)
            return WordPicker.photoWord(for: ctx, labels: labels, in: words, excluding: [], seed: "\(month)-\(hour)")?.word
        }
        let hills = word(10, 16, .clear, 20, ["outdoor", "sky", "blue_sky", "structure", "building", "hill", "land", "skyscraper"])
        XCTAssertNotEqual(hills, "아지랑이", "10월 언덕")
        let lawn = word(10, 0, .clear, 15, ["container", "bottle", "grass", "land", "outdoor"])
        XCTAssertFalse(["산들바람", "길섶"].contains(lawn ?? ""), "바람 없는 자정 잔디: \(lawn ?? "")")
        XCTAssertNotEqual(word(11, 15, .clear, 12, ["outdoor", "sky", "blue_sky", "cord"]), "여우비", "비 안 온 맑은 날")
        XCTAssertNotEqual(word(4, 16, .cloudy, 15, ["rocks", "structure", "liquid", "water"]), "윤슬", "흐린 날 물")
        XCTAssertNotEqual(word(9, 10, nil, nil, ["structure", "wood_processed", "furniture"]), "손때", "그냥 나무 탁자")
        XCTAssertNotEqual(word(6, 15, .cloudy, 22, ["structure", "wood_processed", "furniture", "table", "utensil"]), "먹장구름",
                          "실내 탁자에 먹장구름")
        let beach = word(6, 11, .clear, 26, ["outdoor", "blue_sky", "sky", "liquid", "ocean", "water", "water_body", "people"])
        XCTAssertTrue(["윤슬", "물가"].contains(beach ?? ""), "바다가 주인공인데 \(beach ?? "없음")")
    }

    func testDuskWordsFollowTheSunNotTheClock() {
        var dusk = w("duskfall", subjects: []).asMoment; dusk.sunMin = -8; dusk.sunMax = 0; dusk.hours = Array(12...23)
        XCTAssertEqual(pick(seoul(7, 15, 17, 30), [], [dusk]), [], "7월 17:30 은 해가 26° — 땅거미가 아니다")
        XCTAssertEqual(pick(seoul(7, 15, 20, 0), [], [dusk]), ["duskfall"])
        XCTAssertEqual(pick(seoul(12, 15, 17, 30), [], [dusk]), ["duskfall"], "12월은 같은 말이 다섯 시 반")
    }

    func testHoursAndRawConditionsNarrowWords() {
        var deepNight = w("deepnight", subjects: []).asMoment; deepNight.hours = [23, 0, 1, 2]
        var downpour = w("downpour", subjects: []).asMoment; downpour.conditions = ["heavyRain"]
        XCTAssertEqual(pick(seoul(10, 2, 20), [], [deepNight]), [], "저녁 8시는 깊은 밤이 아니다")
        XCTAssertEqual(pick(seoul(10, 2, 0, 30), [], [deepNight]), ["deepnight"])
        XCTAssertEqual(pick(seoul(7, 2, 15, weather: .rain, condition: "rain"), [], [downpour]), [])
        XCTAssertEqual(pick(seoul(7, 2, 15, weather: .rain, condition: "heavyRain"), [], [downpour]), ["downpour"])
        XCTAssertEqual(pick(seoul(7, 2, 15, weather: .rain), [], [downpour]), [], "원래 날씨를 모르면 작달비라 말하지 않는다")
    }

    func testMoonAgePicksTheShape() {
        var sliver = w("sliver", subjects: ["moon"]); sliver.moonAges = [[0.5, 3], [26.5, 29.1]]
        var c = DateComponents(); c.year = 2024; c.month = 9; c.day = 18; c.hour = 2; c.minute = 34
        let fullMoon = PhotoContext(date: utc.date(from: c)!, calendar: utc)
        XCTAssertEqual(fullMoon.moonAge, 14.8, accuracy: 1, "2024-09-18 보름")
        XCTAssertEqual(pick(fullMoon, ["moon"], [sliver]), [])
        c.month = 10; c.day = 4; c.hour = 12
        XCTAssertEqual(pick(PhotoContext(date: utc.date(from: c)!, calendar: utc), ["moon"], [sliver]), ["sliver"], "삭 이틀 뒤")
    }

    func testPlainWordsComeLast() {
        var plain = w("plain", times: [.noon], subjects: []).asMoment; plain.fallback = true
        let noonish = w("noonish", times: [.noon], subjects: []).asMoment
        XCTAssertEqual(pick(seoul(10, 2, 12), [], [plain, noonish]), ["noonish", "plain"])
        XCTAssertEqual(pick(seoul(10, 2, 12), [], [plain]), ["plain"], "다른 말이 없으면 밋밋한 말이라도")
    }

    func testMoreSpecificMomentWinsWithinTheSameKind() {
        let rain = w("rain", weathers: [.rain], subjects: []).asMoment
        let nightRain = w("nightrain", times: [.night], weathers: [.rain], subjects: []).asMoment
        XCTAssertEqual(pick(seoul(10, 2, 22, weather: .rain), [], [rain, nightRain]).first, "nightrain")
    }

    func testWeekdaysNarrowWords() {
        var office = w("office", subjects: ["laptop"]); office.weekdays = [2, 3, 4, 5, 6]
        XCTAssertEqual(pick(seoul(10, 2, 14), ["laptop"], [office]), ["office"], "2026-10-02 금요일")
        XCTAssertEqual(pick(seoul(10, 3, 14), ["laptop"], [office]), [], "토요일")
    }

    /// Tabber: 「책상 위에 뭐가 있다고만 하면 다 손때, 말벗으로 퉁치던데 그게 너무 싫어서」(2026-10-03).
    func testDeskPhotosSayWhatIsOnTheDesk() async throws {
        let words = await BundledWordSource().words()
        XCTAssertTrue(Set(words.map(\.word)).isDisjoint(with: ["손때", "말벗", "겨를"]))
        func word(_ day: Int, _ hour: Int, _ labels: [String]) -> String? {
            WordPicker.photoWord(for: seoul(10, day, hour, weather: .clear, celsius: 20), labels: labels, in: words,
                                 excluding: [], seed: "desk")?.word
        }
        let desk = ["structure", "wood_processed", "furniture", "table"]
        XCTAssertNotEqual(word(2, 15, desk + ["laptop", "computer"]), "짬", "노트북만 있으면 일하는 중")
        XCTAssertEqual(word(2, 15, desk + ["coffee", "laptop"]), "짬", "평일 낮 노트북 옆 커피")
        XCTAssertNotEqual(word(3, 15, desk + ["coffee", "laptop"]), "짬", "토요일엔 일하다 쉬는 틈이 아니다")
        XCTAssertEqual(word(2, 15, desk + ["book"]), "갈피")
        XCTAssertEqual(word(2, 15, desk + ["toy", "stuffed_animals"]), "놀잇감")
    }

    /// 고른 맥락에서 그 단어가 「틀렸다」고 지워지면, 열 때마다 바뀌고 iCloud 로 계속 올라간다(2026-10-03 교차 검증 — 윤슬·불볕더위).
    func testAPickedWordIsNeverContradictedInTheSameMoment() async throws {
        let words = await BundledWordSource().words()
        let conditions: [String?] = [nil, "clear", "mostlyCloudy", "drizzle", "rain", "heavyRain", "sunShowers", "sleet", "snow",
                                     "flurries", "foggy", "haze", "breezy", "windy", "thunderstorms"]
        var checked = 0
        for month in 1...12 {
            for hour in stride(from: 0, to: 24, by: 2) {
                for condition in conditions {
                    for celsius in [nil, -12.0, 3, 18, 34] as [Double?] {
                        let weather = condition.flatMap(PhotoEnrichment.wordWeather)
                        let ctx = seoul(month, 9, hour, weather: weather, celsius: celsius, condition: condition)
                        let picked = WordPicker.choices(for: ctx, labels: ["outdoor", "sky", "water", "table", "coffee", "laptop"],
                                                        in: words, excluding: [], seed: "p")
                        for w in picked {
                            checked += 1
                            XCTAssertFalse(WordPicker.contradicted(PhotoWord(w), context: ctx, in: words, retired: []),
                                           "\(w.word) — \(month)월 \(hour)시 \(condition ?? "-") \(celsius.map { "\($0)°" } ?? "-")")
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(checked, 10_000)
    }

    func testRainAndFogWordsFollowTheRealWeather() async throws {
        let words = await BundledWordSource().words()
        func first(_ condition: String) -> [String] {
            let ctx = seoul(10, 15, 14, weather: PhotoEnrichment.wordWeather(condition), celsius: 15, condition: condition)
            return (0..<20).compactMap { WordPicker.photoWord(for: ctx, labels: [], in: words, excluding: [], seed: "s\($0)")?.word }
        }
        XCTAssertFalse(first("heavyRain").contains("가랑비"), "폭우에 가는 비")
        XCTAssertTrue(first("heavyRain").allSatisfy { $0 == "작달비" }, "\(Set(first("heavyRain")))")
        XCTAssertFalse(first("thunderstorms").contains("가랑비"))
        XCTAssertTrue(Set(first("haze")).isDisjoint(with: ["는개", "안개비", "밤안개"]), "미세먼지 낀 마른 날에 비 말")
        XCTAssertTrue(Set(first("sleet")).isDisjoint(with: ["가랑비", "빗소리"]), "\(Set(first("sleet")))")
    }

    func testWordFactsUseKoreanTimeWhateverTheDeviceZone() {
        var c = DateComponents(); c.year = 2026; c.month = 10; c.day = 2; c.hour = 14; c.minute = 30   // UTC → 23:30 KST
        c.timeZone = TimeZone(identifier: "UTC")
        let m = Moment(capturedAt: Calendar(identifier: .gregorian).date(from: c)!, colorHex: "#888888", fileName: "x.jpg", source: .app)
        let ctx = PhotoContext(m, labels: [])
        XCTAssertEqual(ctx.hour, 23)
        XCTAssertEqual(ctx.timeBand, .night)
    }

    func testRecentIsExcludedThenReleased() {
        let words = [w("a"), w("b")]
        XCTAssertEqual(pick(dusk, ["sky"], words, recent: ["a"]), ["b"])
        XCTAssertEqual(Set(pick(dusk, ["sky"], words, recent: ["a", "b"])), ["a", "b"], "다 최근이면 반복을 허용한다")
    }

    func testSameSeedSameOrderAndLimit() {
        let words = (0..<20).map { w("w\($0)") }
        let a = WordPicker.candidates(for: dusk, labels: ["sky"], in: words, excluding: [], seed: "photo-1").map(\.id)
        let b = WordPicker.candidates(for: dusk, labels: ["sky"], in: words, excluding: [], seed: "photo-1").map(\.id)
        let c = WordPicker.candidates(for: dusk, labels: ["sky"], in: words, excluding: [], seed: "photo-2").map(\.id)
        XCTAssertEqual(a, b); XCTAssertNotEqual(a, c); XCTAssertEqual(a.count, 8)
    }

    func testFNVIsStableAcrossRuns() {
        XCTAssertEqual(WordPicker.fnv1a("a"), 0xaf63dc4c8601ec8c)
    }

    func testPhotoWordCopiesTheFirstCandidate() throws {
        let pw = try XCTUnwrap(WordPicker.photoWord(for: dusk, labels: ["sky"], in: [w("a")], excluding: [], seed: "s"))
        XCTAssertEqual(pw, PhotoWord(wordID: "a", word: "a", meaning: "뜻 a"))
    }
}

private extension WordEntry {
    var asMoment: WordEntry { var e = self; e.moment = true; return e }
}
