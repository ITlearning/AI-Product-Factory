import Foundation
import Observation

@Observable
public final class DayStore {

    public private(set) var moments: [Moment] = []

    /// 이 기기에서 실제로 바뀐 것만 — applyRemote 는 부르지 않는다(되돌아 올라가면 끝없이 돈다).
    /// 구독 전에 생긴 변경은 모아 두었다가 설정되는 순간 한 번에 넘긴다.
    @ObservationIgnored
    public var onLocalChange: (([StoreChange]) -> Void)? {
        didSet {
            guard let onLocalChange, !unsent.isEmpty else { return }
            let changes = unsent
            unsent = []
            onLocalChange(changes)
        }
    }
    @ObservationIgnored private var unsent: [StoreChange] = []

    private func notify(_ changes: [StoreChange]) {
        guard let onLocalChange else { unsent += changes; return }
        onLocalChange(changes)
    }

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
        notify([.upsert(moment.id)])
        return true
    }

    public func assignWord(_ id: Moment.ID, _ word: PhotoWord) {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].word == nil else { return }
        moments[i].word = word
        save()
        notify([.upsert(id)])
    }

    public func setLabels(_ id: Moment.ID, _ labels: [String]) {
        guard let i = moments.firstIndex(where: { $0.id == id }), moments[i].labels == nil else { return }
        moments[i].labels = labels
        save()
        notify([.upsert(id)])
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
        resolveAssets([(id, assetID)])
    }

    public func resolveAssets(_ pairs: [(Moment.ID, String)]) {
        let index = Dictionary(moments.indices.map { (moments[$0].id, $0) }, uniquingKeysWith: { a, _ in a })
        var changed = false
        for (id, assetID) in pairs {
            guard let i = index[id], moments[i].assetID == nil else { continue }
            moments[i] = reassetted(moments[i], assetID: assetID)
            changed = true
        }
        if changed { save() }
    }

    /// 복원 등으로 바뀐 에셋 ID 로 갈아 끼운다. 알리지 않는다 — assetID 는 이 기기 전용.
    public func reassignAssets(_ pairs: [(Moment.ID, String)]) {
        let index = Dictionary(moments.indices.map { (moments[$0].id, $0) }, uniquingKeysWith: { a, _ in a })
        var changed = false
        for (id, assetID) in pairs {
            guard let i = index[id], let old = moments[i].assetID, old != assetID else { continue }
            moments[i] = reassetted(moments[i], assetID: assetID)
            changed = true
        }
        if changed { save() }
    }

    private func reassetted(_ m: Moment, assetID: String) -> Moment {
        m.withDeviceFields(fileName: Moment.assetFileName(for: assetID), assetID: assetID, originalName: m.originalName)
    }

    public func remove(assetIDs: Set<String>) {
        guard !assetIDs.isEmpty else { return }
        let removed = moments.filter { $0.assetID.map(assetIDs.contains) ?? false }
        guard !removed.isEmpty else { return }
        moments.removeAll { $0.assetID.map(assetIDs.contains) ?? false }
        save()
        notify(removed.map { .delete($0.id) })
    }

    public func setCloudID(_ id: Moment.ID, _ cloudID: String) {
        setCloudIDs([(id, cloudID)])
    }

    /// 같은 cloudID 기록이 이미 있으면 combine 으로 합친다. 저장·알림은 한 번.
    public func setCloudIDs(_ pairs: [(Moment.ID, String)]) {
        var index: [Moment.ID: Int] = [:], byCloud: [String: Int] = [:]
        for (i, m) in moments.enumerated() {
            index[m.id] = i
            if let c = m.cloudID { byCloud[c] = i }
        }
        var dropped = Set<Int>()
        var changes: [StoreChange] = []
        for (id, cloudID) in pairs {
            guard let i = index[id], !dropped.contains(i), moments[i].cloudID == nil else { continue }
            moments[i].cloudID = cloudID
            guard let j = byCloud[cloudID], j != i, !dropped.contains(j) else {
                byCloud[cloudID] = i
                changes.append(.upsert(id))
                continue
            }
            let combined = MomentMerge.combine(moments[i], moments[j])
            let (keep, drop) = combined.id == moments[i].id ? (i, j) : (j, i)
            // i 가 남으면 서버의 i 에는 cloudID 가 없다 — 항상 올린다.
            let needsUpsert = keep == i || !MomentMerge.syncedEqual(combined, moments[j])
            changes.append(.delete(moments[drop].id))
            if needsUpsert { changes.append(.upsert(combined.id)) }
            moments[keep] = combined
            dropped.insert(drop)
            byCloud[cloudID] = keep
        }
        guard !changes.isEmpty else { return }
        let droppedIDs = Set(dropped.map { moments[$0].id })
        moments = moments.enumerated().filter { !dropped.contains($0.offset) }.map(\.element)
        changes.removeAll { if case .upsert(let id) = $0 { return droppedIDs.contains(id) } else { return false } }
        save()
        notify(changes)
    }

    /// upserts 먼저, deletes 나중 — 다른 기기의 delete(a)+upsert(b)(같은 cloudID)를 받을 때 a 의 사진 연결을 b 로 넘기려고.
    @discardableResult
    public func applyRemote(upserts: [Moment], deletes: Set<Moment.ID>) -> [StoreChange] {
        var push: [StoreChange] = []
        var changed = false
        var index: [Moment.ID: Int] = [:], byCloud: [String: Int] = [:]
        for (i, m) in moments.enumerated() {
            index[m.id] = i
            if let c = m.cloudID { byCloud[c] = i }
        }
        for incoming in upserts {
            let remote = incoming.withDeviceFields(
                fileName: Moment.receivedFileName(cloudID: incoming.cloudID, id: incoming.id),
                assetID: nil, originalName: nil)
            if let i = index[remote.id] {
                let merged = MomentMerge.merge(local: moments[i], remote: remote)
                if merged != moments[i] { moments[i] = merged; changed = true }
                if let c = merged.cloudID { byCloud[c] = i }
                if !MomentMerge.syncedEqual(merged, remote) { push.append(.upsert(merged.id)) }
            } else if let cid = remote.cloudID, let j = byCloud[cid] {
                let local = moments[j]
                let combined = MomentMerge.combine(local, remote)
                let remoteWins = combined.id == remote.id
                push.append(.delete(remoteWins ? local.id : remote.id))
                if !MomentMerge.syncedEqual(combined, remoteWins ? remote : local) { push.append(.upsert(combined.id)) }
                if combined != local {
                    moments[j] = combined
                    index[local.id] = nil
                    index[combined.id] = j
                    changed = true
                }
            } else {
                moments.append(remote)
                index[remote.id] = moments.count - 1
                if let c = remote.cloudID { byCloud[c] = moments.count - 1 }
                changed = true
            }
        }
        if !deletes.isEmpty {
            for i in moments.indices where deletes.contains(moments[i].id) {
                let doomed = moments[i]
                guard doomed.assetID != nil, let cid = doomed.cloudID,
                      let k = moments.indices.first(where: {
                          $0 != i && moments[$0].cloudID == cid && moments[$0].assetID == nil
                              && !deletes.contains(moments[$0].id)
                      }) else { continue }
                moments[k] = moments[k].withDeviceFields(fileName: doomed.fileName, assetID: doomed.assetID,
                                                         originalName: doomed.originalName)
            }
            let before = moments.count
            moments.removeAll { deletes.contains($0.id) }
            if moments.count != before { changed = true }
        }
        if changed { save() }
        return push
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

    /// 이 기기 초기화 전용 — 알리면 다른 기기 기록까지 모두 지워진다.
    public func removeAll() {
        moments = []
        save()
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: ShotStore.directory,
                                                 includingPropertiesForKeys: nil)) ?? []
        for f in files { try? fm.removeItem(at: f) }
    }

    // 초 단위(.iso8601)로 저장하면 재실행 뒤 capturedAt 이 잘려 CloudKit 값과 어긋난다.
    private static let fractionalDate: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let wholeSecondDate = ISO8601DateFormatter()

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let text = try c.decode(String.self)
            guard let date = Self.fractionalDate.date(from: text) ?? Self.wholeSecondDate.date(from: text) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "날짜 형식 아님: \(text)")
            }
            return date
        }
        let decoded = (try? decoder.decode([Moment].self, from: data)) ?? []
        moments = decoded.map { m in
            var m = m
            if m.labels == nil { m.word = nil }
            return m
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, e in
            var c = e.singleValueContainer()
            try c.encode(Self.fractionalDate.string(from: date))
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(moments) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
