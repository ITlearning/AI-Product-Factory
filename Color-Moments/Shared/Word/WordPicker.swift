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

    public static func candidates(for ctx: PhotoContext, in words: [WordEntry], excluding recent: Set<String>,
                                  seed: String, limit: Int = 8) -> [WordEntry] {
        let steps = [Check(), Check(weather: false), Check(weather: false, season: false),
                     Check(weather: false, season: false, time: false)]
        var found: [WordEntry] = []
        for k in steps {
            found = words.filter { !recent.contains($0.id) && matches($0, ctx, k) }
            if !found.isEmpty { break }
        }
        if found.isEmpty { found = words }
        return Array(found.sorted { fnv1a(seed + ":" + $0.id) < fnv1a(seed + ":" + $1.id) }.prefix(limit))
    }

    public static func photoWord(for ctx: PhotoContext, in words: [WordEntry], excluding recent: Set<String>,
                                 seed: String) -> PhotoWord? {
        candidates(for: ctx, in: words, excluding: recent, seed: seed).first
            .map { PhotoWord(wordID: $0.id, word: $0.word, meaning: $0.meaning) }
    }

    // Never use Swift's built-in Hasher/hashValue here — its seed is randomized per process,
    // which would break determinism across launches. FNV-1a-64 is required for a stable pick order.
    public static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01b3 }
        return h
    }
}
