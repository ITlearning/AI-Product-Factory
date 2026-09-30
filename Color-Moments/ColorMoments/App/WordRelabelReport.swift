#if DEBUG
import SwiftUI

/// 라벨 기준 전후로 모든 사진의 단어를 다시 뽑아 본다 — 저장하지 않는다.
/// 전: 정밀도 90% 라벨만. 후: 단어 라벨은 70% · 확신도 0.15 이상도. 날씨·시각은 같게, 최근 단어 피하기와 옆 장 합치기는 뺀다.
struct WordRelabelReport: View {
    let store: DayStore

    private struct Row: Identifiable {
        let id: Moment.ID
        let when: String
        let before: String
        let after: String
        let added: [String]
        let beforeFits: Bool
        let afterFits: Bool
    }

    @State private var rows: [Row] = []
    @State private var total = 0

    var body: some View {
        List {
            Section {
                LabeledContent("사진", value: "\(rows.count)/\(total)")
                LabeledContent("대상과 맞춘 단어 (전 → 후)",
                               value: "\(rows.filter(\.beforeFits).count) → \(rows.filter(\.afterFits).count)")
                LabeledContent("단어가 바뀌는 사진", value: "\(changed.count)")
            } footer: {
                Text("저장하지 않는다. 옆 장 합치기·최근 단어 피하기는 빼고 라벨 기준만 비교한다.")
            }
            Section("바뀌는 사진") {
                ForEach(changed) { r in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(r.when)  \(r.before) → \(r.after)")
                        if !r.added.isEmpty {
                            Text("+ " + r.added.joined(separator: ", ")).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                    .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("단어 다시 뽑아 보기")
        .task { await run() }
    }

    private var changed: [Row] { rows.filter { $0.before != $0.after } }

    private func run() async {
        let words = await BundledWordSource().words()
        let vocabulary = Set(words.flatMap(\.subjects))
        let moments = store.moments.sorted { $0.capturedAt < $1.capturedAt }
        total = moments.count
        let format = DateFormatter()
        format.dateFormat = "yy-MM-dd HH:mm"
        for m in moments {
            guard !Task.isCancelled else { return }
            guard let image = await ShotImage.thumbnail(m, maxPixel: 600)?.cgImage else { continue }
            let before = PhotoLabeler.labels(for: image) ?? []
            let after = PhotoLabeler.labels(for: image, vocabulary: vocabulary) ?? []
            let real = m.place?.weather.flatMap { PhotoEnrichment.wordWeather($0.condition) }
            func pick(_ labels: [String]) -> (String, Bool) {
                let seen = Set(labels)
                let ctx = PhotoContext(date: m.capturedAt, weather: real ?? Weather.inferred(from: seen))
                guard let w = WordPicker.candidates(for: ctx, labels: seen, in: words, excluding: [], seed: m.id.uuidString).first
                else { return ("없음", false) }
                return (w.word, !seen.isDisjoint(with: w.subjects))
            }
            let (wb, fb) = pick(before), (wa, fa) = pick(after)
            rows.append(Row(id: m.id, when: format.string(from: m.capturedAt), before: wb, after: wa,
                            added: after.filter { !before.contains($0) }, beforeFits: fb, afterFits: fa))
        }
    }
}
#endif
