import Foundation
import Observation

@Observable
public final class DayStore {

    public private(set) var moments: [Moment] = []

    private let fileURL: URL
    private let closures: DayClosures

    // closures 는 기본값을 주지 않는다 — 묵시적으로 .standard 를 공유하면 테스트가 실기기 저장소를 건드린다.
    public init(fileURL: URL? = nil, closures: DayClosures) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("days.json")
        self.closures = closures
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
        dayKeys.filter(isFinished)
    }

    /// 오늘 이전은 항상, 오늘은 「마무리하기」로 닫혀야 true.
    public func isFinished(_ dayKey: String) -> Bool {
        let today = Moment.dayKey(for: Date())
        if dayKey < today { return true }
        guard dayKey == today else { return false }
        return closures.closedAt(dayKey) != nil
    }

    /// 그 하루의 닫힌 시각 — 마무리하기로 일찍 닫았으면 그 시각, 아니면 자정(새벽 4시) 자연 봉인.
    public func sealDate(on dayKey: String) -> Date? {
        guard let natural = Moment.sealDate(for: dayKey) else { return nil }
        guard let closedAt = closures.closedAt(dayKey) else { return natural }
        return min(closedAt, natural)
    }

    /// 실제로 넣었으면 true, 같은 사진이라 무시했으면 false.
    /// fileName 이 같거나(입양 전 흔한 경우) originalName 이 같으면(입양 뒤 fileName 이 자리
    /// 이름으로 바뀐 뒤 같은 세션이 재전달된 경우) 중복으로 본다.
    @discardableResult
    public func add(_ moment: Moment) -> Bool {
        guard !moments.contains(where: { existing in
            existing.fileName == moment.fileName ||
            (moment.originalName != nil && existing.originalName == moment.originalName)
        }) else { return false }
        moments.append(moment)
        save()
        return true
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

    /// 실제로 입양(assetID 를 채움)했으면 true. 이미 입양됐거나 없는 id 면 false —
    /// 호출부(AssetAdopter)는 이 값으로만 로컬 파일을 지울지 판단해야 한다.
    @discardableResult
    public func adopt(_ id: Moment.ID, assetID: String) -> Bool {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].assetID == nil else { return false }
        let m = moments[i]
        moments[i] = Moment(id: m.id, capturedAt: m.capturedAt, colorHex: m.colorHex,
                             fileName: Moment.assetFileName(for: assetID), source: m.source,
                             word: m.word, labels: m.labels, assetID: assetID,
                             place: m.place, addedAt: m.addedAt, batchID: m.batchID,
                             originalName: m.originalName)
        save()
        return true
    }

    public func remove(assetIDs: Set<String>) {
        guard !assetIDs.isEmpty else { return }
        let kept = moments.filter { !($0.assetID.map(assetIDs.contains) ?? false) }
        guard kept.count != moments.count else { return }
        moments = kept
        save()
    }

    /// 「오늘 마무리하기」를 보여줘도(눌러도) 되는지 — 오늘이고, 사진이 있고, 아직 안 닫혔을 때만.
    public func canClose(_ dayKey: String, now: Date = Date()) -> Bool {
        guard dayKey == Moment.dayKey(for: now), !isFinished(dayKey) else { return false }
        return !moments(on: dayKey).isEmpty
    }

    public func hasSealedMoments(on dayKey: String) -> Bool {
        guard let seal = sealDate(on: dayKey) else { return false }
        return moments(on: dayKey).contains { ($0.addedAt ?? $0.capturedAt) <= seal }
    }

    public func pebbleMoments(on dayKey: String) -> [Moment] {
        let all = moments(on: dayKey)
        guard let seal = sealDate(on: dayKey) else { return all }
        // addedAt 이 없으면(카메라 촬영) capturedAt 으로 비교한다 — 마무리 뒤 찍은 사진까지
        // "기록 안 됨=이전"으로 잘못 포함시키지 않기 위해서.
        let sealed = all.filter { ($0.addedAt ?? $0.capturedAt) <= seal }
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
