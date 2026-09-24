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

    public static func candidates(for ctx: PhotoContext, labels: Set<String>, in words: [WordEntry],
                                  excluding recent: Set<String>, seed: String, limit: Int = 8) -> [WordEntry] {
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
                if !found.isEmpty {
                    return Array(found.sorted { fnv1a(seed + ":" + $0.id) < fnv1a(seed + ":" + $1.id) }.prefix(limit))
                }
            }
        }
        return []
    }

    public static func photoWord(for ctx: PhotoContext, labels: Set<String>, in words: [WordEntry],
                                 excluding recent: Set<String>, seed: String) -> PhotoWord? {
        candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: seed).first
            .map { PhotoWord(wordID: $0.id, word: $0.word, meaning: $0.meaning) }
    }

    // Hasher 금지 — 프로세스마다 시드가 달라 같은 사진의 후보가 바뀐다.
    public static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01b3 }
        return h
    }
}
