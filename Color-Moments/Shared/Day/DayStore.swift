import Foundation
import Observation

@Observable
public final class DayStore {

    public private(set) var moments: [Moment] = []

    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("days.json")
        load()
    }

    public var today: [Moment] { moments(on: Moment.dayKey(for: Date())) }

    public func moments(on dayKey: String) -> [Moment] {
        moments.filter { $0.dayKey == dayKey }.sorted { $0.capturedAt < $1.capturedAt }
    }

    public var dayKeys: [String] {
        Array(Set(moments.map(\.dayKey))).sorted(by: >)
    }

    public var finishedDayKeys: [String] {
        let today = Moment.dayKey(for: Date())
        return dayKeys.filter { $0 < today }
    }

    public func add(_ moment: Moment) {

        guard !moments.contains(where: { $0.fileName == moment.fileName }) else { return }
        moments.append(moment)
        save()
    }

    public func assignWord(_ id: Moment.ID, _ word: PhotoWord) {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].word == nil else { return }
        moments[i].word = word
        save()
    }

    public func setLabels(_ id: Moment.ID, _ labels: [String]) {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].labels == nil else { return }
        moments[i].labels = labels
        save()
    }

    public func recentWordIDs(excluding id: Moment.ID, limit: Int = 14) -> Set<String> {
        let others = moments.filter { $0.id != id && $0.word != nil }
        let ordered: [Moment]
        if let at = moments.first(where: { $0.id == id })?.capturedAt {
            ordered = others.sorted { abs($0.capturedAt.timeIntervalSince(at)) < abs($1.capturedAt.timeIntervalSince(at)) }
        } else {
            ordered = others.sorted { $0.capturedAt > $1.capturedAt }
        }
        return Set(ordered.prefix(limit).compactMap { $0.word?.wordID })
    }

    public func containsAsset(_ id: String) -> Bool {
        moments.contains { $0.assetID == id }
    }

    public var fileBacked: [Moment] { moments.filter { $0.assetID == nil } }

    public func adopt(_ id: Moment.ID, assetID: String) {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].assetID == nil else { return }
        let m = moments[i]
        moments[i] = Moment(id: m.id, capturedAt: m.capturedAt, colorHex: m.colorHex,
                             fileName: Moment.assetFileName(for: assetID), source: m.source,
                             word: m.word, labels: m.labels, assetID: assetID,
                             place: m.place, addedAt: m.addedAt, batchID: m.batchID)
        save()
    }

    public func remove(assetIDs: Set<String>) {
        guard !assetIDs.isEmpty else { return }
        let kept = moments.filter { !($0.assetID.map(assetIDs.contains) ?? false) }
        guard kept.count != moments.count else { return }
        moments = kept
        save()
    }

    public func hasSealedMoments(on dayKey: String) -> Bool {
        guard let seal = Moment.sealDate(for: dayKey) else { return false }
        return moments(on: dayKey).contains { $0.addedAt.map { $0 <= seal } ?? true }
    }

    public func pebbleMoments(on dayKey: String) -> [Moment] {
        let all = moments(on: dayKey)
        guard let seal = Moment.sealDate(for: dayKey) else { return all }
        let sealed = all.filter { m in m.addedAt.map { $0 <= seal } ?? true }
        if !sealed.isEmpty { return sealed }
        guard let firstBatch = all.min(by: { ($0.addedAt ?? .distantFuture) < ($1.addedAt ?? .distantFuture) })?.batchID
        else { return all }
        return all.filter { $0.batchID == firstBatch }
    }

    public func removeAll() {
        moments = []
        save()
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: ShotStore.directory,
                                                 includingPropertiesForKeys: nil)) ?? []
        for f in files { try? fm.removeItem(at: f) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = (try? decoder.decode([Moment].self, from: data)) ?? []
        moments = decoded.map { m in
            var m = m
            if m.labels == nil { m.word = nil }
            return m
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(moments) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
