import Foundation

public struct PhotoWord: Codable, Equatable, Sendable {
    public let wordID: String
    public let word: String
    public let meaning: String

    public init(wordID: String, word: String, meaning: String) {
        self.wordID = wordID; self.word = word; self.meaning = meaning
    }
}

public enum WordPicker {

    /// 뭉뚱그린 라벨 — Vision 은 위 갈래(plant)를 아래 갈래(daffodil)보다 확신해서 늘 앞에 둔다. 하늘은 바깥 사진 거의 전부에 잡힌다.
    /// 구체 라벨의 단어가 늘 앞서고, 이 라벨은 사진에서 앞쪽(단어가 쓰는 라벨 중 두 번째까지)에 잡혔을 때만 근거가 된다
    /// — 하늘 사진 귀퉁이 풀 한 포기로 「푸나무」가 되지 않게.
    static let backdrop: Set<String> = ["sky", "blue_sky", "cloudy", "plant", "people", "adult", "water", "liquid", "land",
                                        "animal", "mammal"]
    static let backdropReach = 2

    enum Verdict { case yes, unknown, no }

    /// 이 단어가 이 순간에 맞나 — 고를 때(yes 만)와 이미 붙은 단어를 지울 때(no 만)가 같은 판정을 쓴다.
    /// 둘이 갈라지면 고르자마자 지워지고, 지운 기기가 다시 올려 기기 사이를 돈다(2026-10-03 교차 검증).
    /// 시각·달·요일·해 높이·달 나이는 늘 안다(한국 시간, 자리를 모르면 서울). 날씨·원래 날씨·기온은 모를 수 있다 — 모르면 고르지도 지우지도 않는다.
    /// 계절은 풀지 않는다 — 계절이 붙은 단어는 계절이 곧 뜻이다(10월의 아지랑이).
    static func judge(_ w: WordEntry, _ ctx: PhotoContext) -> Verdict {
        if !w.times.isEmpty, !w.times.contains(ctx.timeBand) { return .no }
        if !w.hours.isEmpty, !w.hours.contains(ctx.hour) { return .no }
        if !w.weekdays.isEmpty, !w.weekdays.contains(ctx.weekday) { return .no }
        if !w.seasons.isEmpty, !w.seasons.contains(ctx.season) { return .no }
        if !w.months.isEmpty, !w.months.contains(ctx.month) { return .no }
        if !w.solar.isEmpty, !w.solar.contains(ctx.solarKey) { return .no }
        if let min = w.sunMin, ctx.sunAltitude < min { return .no }
        if let max = w.sunMax, ctx.sunAltitude > max { return .no }
        if w.needs.contains(.sun), ctx.sunAltitude < 0 { return .no }
        if !w.moonAges.isEmpty, !w.moonAges.contains(where: { $0.count == 2 && $0[0] <= ctx.moonAge && ctx.moonAge <= $0[1] }) {
            return .no
        }
        var unknown = false
        if !w.lunar.isEmpty {
            // 표가 없으면(확장 등) 음력을 모른다 — no 로 두면 이미 붙은 음력 단어를 지운다.
            if LunarDays.table.isEmpty { unknown = true }
            else if LunarDays.keys(on: ctx.dateKey).isDisjoint(with: w.lunar) { return .no }
        }
        if !w.weathers.isEmpty || w.needs.contains(.sun) {
            if let weather = ctx.weather {
                if !w.weathers.isEmpty, !w.weathers.contains(weather) { return .no }
                if w.needs.contains(.sun), weather != .clear { return .no }
            } else {
                unknown = true
            }
        }
        if !w.conditions.isEmpty {
            if let c = ctx.condition { if !w.conditions.contains(c) { return .no } } else { unknown = true }
        }
        if w.minCelsius != nil || w.maxCelsius != nil {
            if let c = ctx.celsius {
                if let min = w.minCelsius, c < min { return .no }
                if let max = w.maxCelsius, c > max { return .no }
            } else {
                unknown = true
            }
        }
        return unknown ? .unknown : .yes
    }

    private static func fits(_ w: WordEntry, _ ctx: PhotoContext) -> Bool { judge(w, ctx) == .yes }

    /// banned — 「이 단어는 아니에요」로 버린 단어. recent 와 달리 끝까지 안 쓴다.
    /// labels 는 Vision 이 내준 순서(확신도 순) 그대로 — 앞에 잡힌 대상의 단어가 이긴다.
    public static func candidates(for ctx: PhotoContext, labels: [String], in words: [WordEntry],
                                  excluding recent: Set<String>, seed: String, limit: Int = 8,
                                  banned: Set<String> = []) -> [WordEntry] {
        let words = words.filter { !banned.contains($0.id) }
        let seen = Set(labels)
        let vocabulary = Set(words.flatMap(\.subjects))
        let leads = Set(labels.filter(vocabulary.contains).prefix(backdropReach))
        let usable = seen.filter { !backdrop.contains($0) || leads.contains($0) }
        let pool = words.filter {
            !$0.subjects.isEmpty && !usable.isDisjoint(with: $0.subjects) && ($0.with.isEmpty || !seen.isDisjoint(with: $0.with))
                && fits($0, ctx)
        }
        for skipRecent in [true, false] {
            let found = pool.filter { !(skipRecent && recent.contains($0.id)) }
            if !found.isEmpty { return ranked(found, seed, limit, labels: labels) }
        }
        return moment(for: ctx, in: words, excluding: recent, seed: seed, limit: limit)
    }

    /// 사진에 맞는 말이 없으면 그 순간을 말하는 단어로 — 비워 두지 않는다(2026-10-01 Tabber).
    /// 날씨·볕 → 기온 → 때(시각·해·달) → 철 차례, 같은 갈래에선 조건이 많은(더 꼭 맞는) 단어부터. 밋밋한 말(fallback)은 맨 뒤.
    /// 대상과 상관없는 「때」의 말만 쓴다 — 신발 사진에 「먹장구름」이 붙으면 거짓말이다.
    private static func moment(for ctx: PhotoContext, in words: [WordEntry], excluding recent: Set<String>,
                               seed: String, limit: Int) -> [WordEntry] {
        let moments = words.filter { $0.moment && fits($0, ctx) }
        for skipRecent in [true, false] {
            let found = moments.filter { !(skipRecent && recent.contains($0.id)) }
            guard !found.isEmpty else { continue }
            let keyed = found.map { (w: $0, f: $0.fallback ? 1 : 0, t: tier($0), s: -specificity($0), h: fnv1a(seed + ":" + $0.id)) }
            return Array(keyed.sorted { ($0.f, $0.t, $0.s, $0.h) < ($1.f, $1.t, $1.s, $1.h) }.map(\.w).prefix(limit))
        }
        return []
    }

    private static func tier(_ w: WordEntry) -> Int {
        if !w.weathers.isEmpty || !w.conditions.isEmpty || !w.needs.isEmpty { return 0 }
        if w.minCelsius != nil || w.maxCelsius != nil { return 1 }
        if !w.times.isEmpty || !w.hours.isEmpty || w.sunMin != nil || w.sunMax != nil || !w.moonAges.isEmpty { return 2 }
        return 3
    }

    /// 조건 갈래 수 — 밤비(비 + 밤)가 빗소리(비)보다 그 순간에 꼭 맞는다.
    /// 원래 날씨 하나만 받는 말(작달비 = heavyRain)은 그 날씨에 가장 꼭 맞아 한 갈래를 더 쳐 준다.
    static func specificity(_ w: WordEntry) -> Int {
        [!w.weathers.isEmpty || !w.conditions.isEmpty, w.conditions.count == 1, !w.needs.isEmpty, !w.times.isEmpty || !w.hours.isEmpty,
         w.sunMin != nil || w.sunMax != nil, !w.seasons.isEmpty || !w.months.isEmpty,
         w.minCelsius != nil || w.maxCelsius != nil, !w.moonAges.isEmpty, !w.with.isEmpty, !w.weekdays.isEmpty].filter { $0 }.count
    }

    /// 단어의 대상이 사진에서 몇 번째로 잡혔나 — 작을수록 주인공. 하늘은 모든 대상 뒤.
    static func prominence(_ w: WordEntry, labels: [String]) -> Int {
        let hits = labels.enumerated().filter { w.subjects.contains($0.element) }
        guard let best = hits.min(by: { rank($0, labels.count) < rank($1, labels.count) }) else { return Int.max }
        return rank(best, labels.count)
    }

    private static func rank(_ hit: (offset: Int, element: String), _ count: Int) -> Int {
        (backdrop.contains(hit.element) ? count : 0) + hit.offset
    }

    private static func ranked(_ words: [WordEntry], _ seed: String, _ limit: Int, labels: [String]) -> [WordEntry] {
        let keyed = words.map {
            (w: $0, p: prominence($0, labels: labels), f: $0.fallback ? 1 : 0, s: -specificity($0), h: fnv1a(seed + ":" + $0.id))
        }
        return Array(keyed.sorted { ($0.p, $0.f, $0.s, $0.h) < ($1.p, $1.f, $1.s, $1.h) }.map(\.w).prefix(limit))
    }

    public static func photoWord(for ctx: PhotoContext, labels: [String], in words: [WordEntry],
                                 excluding recent: Set<String>, seed: String, banned: Set<String> = []) -> PhotoWord? {
        candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned).first.map(PhotoWord.init)
    }

    /// 고르기 후보 — 규칙 후보에 그 순간의 말(틀릴 수 없는 단어)을 더한다.
    /// 규칙 후보가 하나뿐이어도 고를 여지를 준다.
    public static func choices(for ctx: PhotoContext, labels: [String], in words: [WordEntry],
                               excluding recent: Set<String>, seed: String, banned: Set<String> = []) -> [WordEntry] {
        let rule = candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned)
        let safe = moment(for: ctx, in: words.filter { !banned.contains($0.id) }, excluding: recent, seed: seed, limit: 4)
        return rule + safe.filter { s in !rule.contains { $0.id == s.id } }
    }

    /// 이미 붙은 단어를 아는 사실이 뒤집나 — 그러면 지우고 다시 고른다(2026-10-03 Tabber: 틀린 것만 다시).
    /// 모르는 날씨·기온은 뒤집지 못하고, 대상이 덜 맞는 정도로는 지우지 않는다. 모르는 id 는 새 버전의 단어라 둔다.
    public static func contradicted(_ word: PhotoWord, context ctx: PhotoContext, in words: [WordEntry],
                                    retired: Set<String>) -> Bool {
        if retired.contains(word.wordID) { return true }
        guard let w = words.first(where: { $0.id == word.wordID }) else { return false }
        return judge(w, ctx) == .no
    }

    public static func modelCandidates(for ctx: PhotoContext, in words: [WordEntry], excluding recent: Set<String>,
                                       banned: Set<String>, pebbleName: String?) -> [WordEntry] {
        words.filter {
            !$0.rest && !banned.contains($0.id) && !recent.contains($0.id) && $0.word != pebbleName && judge($0, ctx) == .yes
        }
    }

    public static func best(_ scores: [String: Float], among words: [WordEntry], seed: String,
                            notInGroupOf skip: WordEntry?) -> WordEntry? {
        words.filter { scores[$0.id]?.isFinite == true && (skip == nil || $0.group != skip?.group) }
            .map { (w: $0, s: (scores[$0.id]! * 1000).rounded(), h: fnv1a(seed + ":" + $0.id)) }
            .min { ($0.s, $1.h) > ($1.s, $0.h) }?.w
    }

    // Hasher 금지 — 프로세스마다 시드가 달라 같은 사진의 후보가 바뀐다.
    public static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01b3 }
        return h
    }
}

extension PhotoWord {
    public init(_ entry: WordEntry) { self.init(wordID: entry.id, word: entry.word, meaning: entry.meaning) }
}

extension Moment {
    /// 사진 보기에 보일 단어 — 아는 사실이 뒤집은 단어·뺀(retired) 단어는 가리고, 열 때 새로 골라 단어와 라벨을 한 번에 바꾼다.
    /// 불러올 때 지우지 않는다 — 빈 단어가 iCloud 로 먼저 올라가면 옛 단어를 든 기기가 되올려 새로 고른 단어를 이긴다(2026-10-03 교차 검증 N2).
    func standingWord(in words: [WordEntry] = BundledWordSource.cached, retired: Set<String> = BundledWordSource.retired) -> PhotoWord? {
        guard let word, let labels else { return nil }
        return WordPicker.contradicted(word, context: PhotoContext(self, labels: labels), in: words, retired: retired) ? nil : word
    }
}
