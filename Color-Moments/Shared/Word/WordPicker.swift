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

    private struct Check { var weather = true, season = true, time = true }

    private static func matches(_ w: WordEntry, _ ctx: PhotoContext, _ k: Check) -> Bool {
        if k.time, !w.times.isEmpty, !w.times.contains(ctx.timeBand) { return false }
        if k.season, !w.seasons.isEmpty, !w.seasons.contains(ctx.season) { return false }
        if k.weather, !w.weathers.isEmpty {
            guard let weather = ctx.weather, w.weathers.contains(weather) else { return false }
        }
        return true
    }

    /// banned — 「이 단어는 아니에요」로 버린 단어. recent 와 달리 끝까지 안 쓴다.
    public static func candidates(for ctx: PhotoContext, labels: Set<String>, in words: [WordEntry],
                                  excluding recent: Set<String>, seed: String, limit: Int = 8,
                                  banned: Set<String> = []) -> [WordEntry] {
        let words = words.filter { !banned.contains($0.id) }
        var pool = words.filter { !$0.subjects.isEmpty && !labels.isDisjoint(with: $0.subjects) }
        if let weather = ctx.weather {
            // 날씨를 알면 그 날씨와 맞는 말만 — 다른 날씨 말은 끝까지 안 쓴다.
            pool = pool.filter { $0.weathers.isEmpty || $0.weathers.contains(weather) }
        } else {
            // 날씨를 모르는 사진에 날씨 말이 붙으면 영구히 틀린 채 남는다.
            pool = pool.filter { $0.weathers.isEmpty }
        }
        let steps = [Check(weather: false), Check(weather: false, season: false)]
        for skipRecent in [true, false] {
            for k in steps {
                let found = pool.filter { !(skipRecent && recent.contains($0.id)) && matches($0, ctx, k) }
                if !found.isEmpty { return ranked(found, seed, limit) }
            }
        }
        return moment(for: ctx, in: words, excluding: recent, seed: seed, limit: limit)
    }

    /// 사진에 맞는 말이 없으면 그 순간을 말하는 단어로 — 비워 두지 않는다(2026-10-01 Tabber).
    /// 실제 날씨 → 시간대 → 계절 차례. 대상과 상관없는 「때」의 말만 쓴다 — 신발 사진에 「달무리」가 붙으면 거짓말이다.
    private static func moment(for ctx: PhotoContext, in words: [WordEntry], excluding recent: Set<String>,
                               seed: String, limit: Int) -> [WordEntry] {
        let moments = words.filter(\.moment)
        let weatherWords = ctx.weather.map { weather in moments.filter { $0.weathers.contains(weather) } } ?? []
        let timeWords = moments.filter { $0.weathers.isEmpty && !$0.times.isEmpty }
        let seasonWords = moments.filter { $0.weathers.isEmpty && $0.times.isEmpty }
        let tiers = [
            weatherWords.filter { matches($0, ctx, Check(weather: false)) },
            weatherWords.filter { matches($0, ctx, Check(weather: false, season: false)) },
            timeWords.filter { matches($0, ctx, Check(weather: false)) },
            timeWords.filter { matches($0, ctx, Check(weather: false, season: false)) },
            seasonWords.filter { matches($0, ctx, Check(weather: false)) },
        ]
        for skipRecent in [true, false] {
            for tier in tiers {
                let found = tier.filter { !(skipRecent && recent.contains($0.id)) }
                if !found.isEmpty { return ranked(found, seed, limit) }
            }
        }
        return []
    }

    private static func ranked(_ words: [WordEntry], _ seed: String, _ limit: Int) -> [WordEntry] {
        Array(words.sorted { fnv1a(seed + ":" + $0.id) < fnv1a(seed + ":" + $1.id) }.prefix(limit))
    }

    public static func photoWord(for ctx: PhotoContext, labels: Set<String>, in words: [WordEntry],
                                 excluding recent: Set<String>, seed: String, banned: Set<String> = []) -> PhotoWord? {
        candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned).first.map(PhotoWord.init)
    }

    /// 모델(Apple Intelligence)에 넘길 후보 — 규칙 후보에 그 순간의 말(틀릴 수 없는 단어)을 더한다.
    /// 규칙 후보가 하나뿐이어도(바다 사진에 land 만 잡혀 「아지랑이」) 모델이 고를 여지를 준다.
    public static func choices(for ctx: PhotoContext, labels: Set<String>, in words: [WordEntry],
                               excluding recent: Set<String>, seed: String, banned: Set<String> = []) -> [WordEntry] {
        let rule = candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned)
        let safe = moment(for: ctx, in: words.filter { !banned.contains($0.id) }, excluding: recent, seed: seed, limit: 4)
        return rule + safe.filter { s in !rule.contains { $0.id == s.id } }
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
