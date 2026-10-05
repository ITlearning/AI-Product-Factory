#if DEBUG
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// 기기에서 학생 모델의 시간과 1등을 잰다 — 단어는 저장하지 않는다. 표(probe.tsv)와 모델에 넣은 224px 그림을 맥으로 보내
/// workshop/parity.py 가 같은 그림·같은 후보로 맥 계산과 1등을 맞춰 본다(입력 차이를 뺀 계산 일치).
/// 1등은 최근 단어·조약돌 이름·금지 없이 고른다. 고르기 층은 vDSP 라 Debug 빌드여도 시간이 거의 같다.
struct WordModelProbe: View {
    let store: DayStore

    private struct Row: Identifiable {
        let id: Moment.ID
        let key: String
        let word: String
        let pool: [String]
        let thumb: Double, label: Double, score: Double
        var pick: Double { label + score }
    }

    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var failed = 0

    var body: some View {
        List {
            Section {
                LabeledContent("사진", value: "\(rows.count)/\(total)" + (failed > 0 ? " · 실패 \(failed)" : ""))
                if let first = rows.first { LabeledContent("첫 사진 (첫 예측 포함)", value: ms(first.pick)) }
                LabeledContent("한 장 중앙값 (라벨+인코더+층)", value: ms(median(rest.map(\.pick))))
                LabeledContent("한 장 90%", value: ms(percentile(0.9)))
                LabeledContent("가장 느림", value: ms(rest.map(\.pick).max()))
                LabeledContent("썸네일 중앙값 (따로)", value: ms(median(rest.map(\.thumb))))
                ShareLink(items: files) { Label("표·그림 보내기 (\(files.count)개)", systemImage: "square.and.arrow.up") }
                    .disabled(rows.isEmpty || rows.count < total - failed)
            } footer: {
                Text("기준: 한 장 ≤ 200ms (첫 사진 빼고). 다 재야 보내기가 켜진다.")
            }
            Section("사진별") {
                ForEach(rows) { r in
                    Text("\(r.key)  \(r.word)  \(ms(r.pick))").font(.caption.monospaced()).textSelection(.enabled)
                }
            }
        }
        .navigationTitle("학생 모델 재기")
        .task { await run() }
    }

    private var rest: [Row] { Array(rows.dropFirst()) }

    private func percentile(_ p: Double) -> Double? {
        let s = rest.map(\.pick).sorted()
        return s.isEmpty ? nil : s[min(s.count - 1, Int(Double(s.count) * p))]
    }

    private func median(_ xs: [Double]) -> Double? { xs.sorted().dropFirst(xs.count / 2).first }

    private func ms(_ s: Double?) -> String { s.map { String(format: "%.0fms", $0 * 1000) } ?? "—" }

    private static let folder = FileManager.default.temporaryDirectory.appendingPathComponent("word-probe", isDirectory: true)

    private var files: [URL] {
        let tsv = Self.folder.appendingPathComponent("probe.tsv")
        let text = (["key\tword\tthumb_ms\tlabel_ms\tscore_ms\tpool"] + rows.map {
            "\($0.key)\t\($0.word)\t\(Int($0.thumb * 1000))\t\(Int($0.label * 1000))\t\(Int($0.score * 1000))\t\($0.pool.joined(separator: ","))"
        }).joined(separator: "\n")
        try? text.write(to: tsv, atomically: true, encoding: .utf8)
        return [tsv] + rows.map { Self.folder.appendingPathComponent($0.key + ".png") }
    }

    private static func savePNG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    private func run() async {
        let words = await BundledWordSource().words()
        let vocabulary = Set(words.flatMap(\.subjects))
        let moments = store.moments.sorted { $0.capturedAt < $1.capturedAt }
        total = moments.count
        try? FileManager.default.removeItem(at: Self.folder)
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let clock = ContinuousClock()
        func seconds(_ d: Duration) -> Double { Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18 }
        for m in moments {
            guard !Task.isCancelled else { return }
            let t0 = clock.now
            guard let image = await ShotImage.thumbnail(m, maxPixel: 600), let cg = WordModel.upright(image) else {
                failed += 1; continue
            }
            let t1 = clock.now
            let labels = PhotoLabeler.labels(for: cg, vocabulary: vocabulary) ?? []
            let t2 = clock.now
            guard let scores = try? await WordModel.scores(for: cg) else { failed += 1; continue }
            let t3 = clock.now
            let ctx = PhotoContext(m, labels: m.labels ?? labels)
            let pool = WordPicker.modelCandidates(for: ctx, in: words, excluding: [], banned: [], pebbleName: nil)
            let word = WordPicker.best(scores, among: pool, seed: m.id.uuidString, notInGroupOf: nil)?.word ?? "없음"
            let key = "m-" + m.id.uuidString.prefix(8)
            if let input = WordImage.input(from: cg) { Self.savePNG(input, to: Self.folder.appendingPathComponent(key + ".png")) }
            rows.append(Row(id: m.id, key: key, word: word, pool: pool.map(\.id),
                            thumb: seconds(t1 - t0), label: seconds(t2 - t1), score: seconds(t3 - t2)))
        }
    }
}
#endif
