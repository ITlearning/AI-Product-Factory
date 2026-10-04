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
            } catch WordScorer.Failure.broken {
            } catch {
                // 사진 창을 닫아 취소된 것은 실패가 아니다.
                if error is CancellationError || Task.isCancelled { return .later }
                attempts.fail(m.id)
                if attempts.failures(m.id) < WordAttempts.limit { return .later }
            }
        }
        let open = words.filter { $0.word != pebbleName }
        let passes = skip.map { s in [open.filter { $0.group != s.group }, open] } ?? [open]
        for words in passes {
            let rule = WordPicker.candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned)
            let pool = WordPicker.choices(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned)
            if let first = rule.first ?? pool.first {
                attempts.clear(m.id)
                return .word(first, pool: pool)
            }
        }
        return nil
    }
}
