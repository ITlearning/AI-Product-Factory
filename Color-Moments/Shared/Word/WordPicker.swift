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

    /// 하늘은 바깥 사진 거의 전부에 크게 잡힌다 — 대상이 따로 있으면 그 대상의 단어가 앞선다.
    static let backdrop: Set<String> = ["sky", "blue_sky", "cloudy"]

    /// 시간대·계절·달·주장(해·기온). 계절도 풀지 않는다 — 계절이 붙은 단어는 계절이 곧 뜻이다(10월의 아지랑이).
    private static func fits(_ w: WordEntry, _ ctx: PhotoContext) -> Bool {
        if !w.times.isEmpty, !w.times.contains(ctx.timeBand) { return false }
        if !w.seasons.isEmpty, !w.seasons.contains(ctx.season) { return false }
        if !w.months.isEmpty, !w.months.contains(ctx.month) { return false }
        if w.needs.contains(.sun), ctx.weather != .clear || ctx.timeBand == .night { return false }
        if let min = w.minCelsius { guard let c = ctx.celsius, c >= min else { return false } }
        if let max = w.maxCelsius { guard let c = ctx.celsius, c <= max else { return false } }
        return true
    }

    /// 날씨를 알면 그 날씨와 맞는 말만, 모르면 날씨 말은 안 쓴다 — 틀린 날씨 말은 영구히 남는다.
    private static func weatherAllows(_ w: WordEntry, _ ctx: PhotoContext) -> Bool {
        guard !w.weathers.isEmpty else { return true }
        guard let weather = ctx.weather else { return false }
        return w.weathers.contains(weather)
    }

    /// banned — 「이 단어는 아니에요」로 버린 단어. recent 와 달리 끝까지 안 쓴다.
    /// labels 는 Vision 이 내준 순서(확신도 순) 그대로 — 앞에 잡힌 대상의 단어가 이긴다.
    public static func candidates(for ctx: PhotoContext, labels: [String], in words: [WordEntry],
                                  excluding recent: Set<String>, seed: String, limit: Int = 8,
                                  banned: Set<String> = []) -> [WordEntry] {
        let words = words.filter { !banned.contains($0.id) }
        let seen = Set(labels)
        let pool = words.filter {
            !$0.subjects.isEmpty && !seen.isDisjoint(with: $0.subjects) && ($0.with.isEmpty || !seen.isDisjoint(with: $0.with))
                && weatherAllows($0, ctx) && fits($0, ctx)
        }
        for skipRecent in [true, false] {
            let found = pool.filter { !(skipRecent && recent.contains($0.id)) }
            if !found.isEmpty { return ranked(found, seed, limit, labels: labels) }
        }
        return moment(for: ctx, in: words, excluding: recent, seed: seed, limit: limit)
    }

    /// 사진에 맞는 말이 없으면 그 순간을 말하는 단어로 — 비워 두지 않는다(2026-10-01 Tabber).
    /// 실제 날씨 → 시간대 → 계절 차례. 대상과 상관없는 「때」의 말만 쓴다 — 신발 사진에 「먹장구름」이 붙으면 거짓말이다.
    private static func moment(for ctx: PhotoContext, in words: [WordEntry], excluding recent: Set<String>,
                               seed: String, limit: Int) -> [WordEntry] {
        let moments = words.filter { $0.moment && fits($0, ctx) }
        let tiers = [
            ctx.weather.map { weather in moments.filter { $0.weathers.contains(weather) } } ?? [],
            moments.filter { $0.weathers.isEmpty && !$0.times.isEmpty },
            moments.filter { $0.weathers.isEmpty && $0.times.isEmpty },
        ]
        for skipRecent in [true, false] {
            for tier in tiers {
                let found = tier.filter { !(skipRecent && recent.contains($0.id)) }
                if !found.isEmpty { return ranked(found, seed, limit, labels: []) }
            }
        }
        return []
    }

    /// 단어의 대상이 사진에서 몇 번째로 잡혔나 — 작을수록 주인공. 하늘은 모든 대상 뒤.
    static func prominence(_ w: WordEntry, labels: [String]) -> Int {
        guard let hit = labels.enumerated().first(where: { w.subjects.contains($0.element) }) else { return Int.max }
        return (backdrop.contains(hit.element) ? labels.count : 0) + hit.offset
    }

    private static func ranked(_ words: [WordEntry], _ seed: String, _ limit: Int, labels: [String]) -> [WordEntry] {
        let keyed = words.map { (w: $0, p: prominence($0, labels: labels), h: fnv1a(seed + ":" + $0.id)) }
        return Array(keyed.sorted { ($0.p, $0.h) < ($1.p, $1.h) }.map(\.w).prefix(limit))
    }

    public static func photoWord(for ctx: PhotoContext, labels: [String], in words: [WordEntry],
                                 excluding recent: Set<String>, seed: String, banned: Set<String> = []) -> PhotoWord? {
        candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned).first.map(PhotoWord.init)
    }

    /// 모델(Apple Intelligence)에 넘길 후보 — 규칙 후보에 그 순간의 말(틀릴 수 없는 단어)을 더한다.
    /// 규칙 후보가 하나뿐이어도 모델이 고를 여지를 준다.
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
        if !w.times.isEmpty, !w.times.contains(ctx.timeBand) { return true }
        if !w.seasons.isEmpty, !w.seasons.contains(ctx.season) { return true }
        if !w.months.isEmpty, !w.months.contains(ctx.month) { return true }
        if w.needs.contains(.sun), ctx.timeBand == .night { return true }
        if let weather = ctx.weather {
            if !w.weathers.isEmpty, !w.weathers.contains(weather) { return true }
            if w.needs.contains(.sun), weather != .clear { return true }
        }
        if let c = ctx.celsius {
            if let min = w.minCelsius, c < min { return true }
            if let max = w.maxCelsius, c > max { return true }
        }
        return false
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
    /// 불러올 때 — labels 없이 붙은 단어(사진을 안 보고 고른 옛 규칙)와 아는 사실이 뒤집는 단어를 지운다. 사진을 열면 다시 고른다.
    func checkingWord(in words: [WordEntry], retired: Set<String>) -> Moment {
        guard let word else { return self }
        var m = self
        if let labels {
            if WordPicker.contradicted(word, context: PhotoContext(self, labels: labels), in: words, retired: retired) { m.word = nil }
        } else {
            m.word = nil
        }
        return m
    }
}
