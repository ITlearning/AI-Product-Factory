import Foundation
import Observation

@Observable
public final class DayStore {

    public private(set) var moments: [Moment] = []

    /// 이 기기에서 실제로 바뀐 것만 — applyRemote 는 부르지 않는다(되돌아 올라가면 끝없이 돈다).
    @ObservationIgnored
    public var onLocalChange: (([StoreChange]) -> Void)?

    private let fileURL: URL
    private let closures: DayClosures

    public init(fileURL: URL? = nil, closures: DayClosures = DayClosures()) {
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
        onLocalChange?([.upsert(moment.id)])
        return true
    }

    public func assignWord(_ id: Moment.ID, _ word: PhotoWord) {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].word == nil else { return }
        moments[i].word = word
        save()
        onLocalChange?([.upsert(id)])
    }

    public func setLabels(_ id: Moment.ID, _ labels: [String]) {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].labels == nil else { return }
        moments[i].labels = labels
        save()
        onLocalChange?([.upsert(id)])
    }

    public func moment(_ id: Moment.ID) -> Moment? { moments.first { $0.id == id } }

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

    /// 이 기기에 원본 파일이 있는 기록만 — 자리 이름(asset-·remote-)은 파일이 없다.
    public var fileBacked: [Moment] {
        moments.filter { $0.assetID == nil && !$0.fileName.hasPrefix("asset-") && !$0.fileName.hasPrefix("remote-") }
    }

    public var unresolved: [Moment] { moments.filter { $0.assetID == nil && $0.cloudID != nil } }

    /// 실제로 입양(assetID 를 채움)했으면 true. 이미 입양됐거나 없는 id 면 false —
    /// 호출부(AssetAdopter)는 이 값으로만 로컬 파일을 지울지 판단해야 한다.
    @discardableResult
    public func adopt(_ id: Moment.ID, assetID: String) -> Bool {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].assetID == nil else { return false }
        moments[i] = reassetted(moments[i], assetID: assetID)
        save()
        return true
    }

    /// 받은 기록(assetID 없음)에 이 기기 사진을 다시 찾아 붙인다. adopt 와 달리 알리지 않는다 — assetID 는 이 기기 전용.
    public func resolveAsset(_ id: Moment.ID, assetID: String) {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].assetID == nil else { return }
        moments[i] = reassetted(moments[i], assetID: assetID)
        save()
    }

    private func reassetted(_ m: Moment, assetID: String) -> Moment {
        Moment(id: m.id, capturedAt: m.capturedAt, colorHex: m.colorHex,
               fileName: Moment.assetFileName(for: assetID), source: m.source,
               word: m.word, labels: m.labels, assetID: assetID,
               place: m.place, addedAt: m.addedAt, batchID: m.batchID,
               originalName: m.originalName, cloudID: m.cloudID)
    }

    public func remove(assetIDs: Set<String>) {
        guard !assetIDs.isEmpty else { return }
        let removed = moments.filter { $0.assetID.map(assetIDs.contains) ?? false }
        guard !removed.isEmpty else { return }
        moments.removeAll { $0.assetID.map(assetIDs.contains) ?? false }
        save()
        onLocalChange?(removed.map { .delete($0.id) })
    }

    public func setCloudID(_ id: Moment.ID, _ cloudID: String) {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].cloudID == nil else { return }
        moments[i].cloudID = cloudID
        if let j = moments.firstIndex(where: { $0.id != id && $0.cloudID == cloudID }) {
            let (winner, loser) = MomentMerge.keeps(moments[i], over: moments[j]) ? (i, j) : (j, i)
            // winner 가 이 기기 것(assetID 있음)이면 merge 로 덮지 않는다 — merge 는 assetID 를 loser 것으로 가져간다.
            let merged = moments[winner].assetID != nil ? moments[winner] : MomentMerge.merge(local: moments[loser], remote: moments[winner])
            let loserID = moments[loser].id
            moments[winner] = merged
            moments.remove(at: loser)
            save()
            onLocalChange?([.delete(loserID), .upsert(merged.id)])
            return
        }
        save()
        onLocalChange?([.upsert(id)])
    }

    @discardableResult
    public func applyRemote(upserts: [Moment], deletes: Set<Moment.ID>) -> [StoreChange] {
        var push: [StoreChange] = []
        var changed = false
        if !deletes.isEmpty {
            let before = moments.count
            moments.removeAll { deletes.contains($0.id) }
            changed = moments.count != before
        }
        for remote in upserts {
            if let i = moments.firstIndex(where: { $0.id == remote.id }) {
                let merged = MomentMerge.merge(local: moments[i], remote: remote)
                if merged != moments[i] { moments[i] = merged; changed = true }
                if !MomentMerge.syncedEqual(merged, remote) { push.append(.upsert(merged.id)) }
            } else if let cid = remote.cloudID, let j = moments.firstIndex(where: { $0.cloudID == cid }) {
                if MomentMerge.keeps(remote, over: moments[j]) {
                    let loser = moments[j]
                    moments[j] = MomentMerge.merge(local: loser, remote: remote)
                    push.append(.delete(loser.id))
                    changed = true
                } else {
                    push.append(.delete(remote.id))
                }
            } else {
                moments.append(remote)
                changed = true
            }
        }
        if changed { save() }
        return push
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
        let removed = moments
        moments = []
        save()
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: ShotStore.directory,
                                                 includingPropertiesForKeys: nil)) ?? []
        for f in files { try? fm.removeItem(at: f) }
        if !removed.isEmpty { onLocalChange?(removed.map { .delete($0.id) }) }
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
