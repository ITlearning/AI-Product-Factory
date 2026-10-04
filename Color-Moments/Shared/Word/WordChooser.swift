import Foundation

public enum WordChooser {
    public enum Outcome { case word(WordEntry, pool: [WordEntry]); case later }

    public static func choose(moment m: Moment, context ctx: PhotoContext, labels: [String], words: [WordEntry],
                              recent: Set<String>, banned: Set<String>, pebbleName: String?, skip: WordEntry?,
                              attempts: WordAttempts) async -> Outcome? {
        let seed = m.id.uuidString
        if WordScorer.score != nil, attempts.failures(m.id) < WordAttempts.limit {
            do {
                let scores = try await WordScorer.scores(for: m)
                for avoid in [recent, []] {
                    let pool = WordPicker.modelCandidates(for: ctx, in: words, excluding: avoid, banned: banned, pebbleName: pebbleName)
                    if let w = WordPicker.best(scores, among: pool, seed: seed, notInGroupOf: skip) {
                        attempts.clear(m.id)
                        return .word(w, pool: pool)
                    }
                }
            } catch {
                attempts.fail(m.id)
                return .later
            }
        }
        let rule = WordPicker.candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned)
        let pool = WordPicker.choices(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned)
        return (rule.first ?? pool.first).map { .word($0, pool: pool) }
    }
}
