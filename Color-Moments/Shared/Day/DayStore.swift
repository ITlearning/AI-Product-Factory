import Foundation
import Observation

@Observable
public final class DayStore {

    public private(set) var moments: [Moment] = [] {
        didSet { dayIndex = nil }
    }

    private struct DayIndex {
        let byDay: [String: [Moment]]
        let keys: [String]
        let zone: String
    }
    @ObservationIgnored private var dayIndex: DayIndex?

    // 캐시가 맞아도 moments 를 읽는다 — 안 읽으면 뷰가 이 저장소를 관찰하지 않아 새 기록을 못 본다.
    private var index: DayIndex {
        let current = moments
        let zone = Moment.zoneIdentifier
        if let dayIndex, dayIndex.zone == zone { return dayIndex }
        var byDay: [String: [Moment]] = [:]
        for m in current { byDay[m.dayKey, default: []].append(m) }
        for key in byDay.keys { byDay[key]?.sort { $0.capturedAt < $1.capturedAt } }
        let built = DayIndex(byDay: byDay, keys: byDay.keys.sorted(by: >), zone: zone)
        dayIndex = built
        return built
    }

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
    @ObservationIgnored private let writer: CoalescingWriter

    /// days.json 을 다 읽었으면 true. 백그라운드 로드 중엔 빈 화면 안내를 띄우면 안 된다.
    public private(set) var isLoaded = true
    @ObservationIgnored private var loadWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var saveDeferred = false

    // closures 는 기본값을 주지 않는다 — 묵시적으로 .standard 를 공유하면 테스트가 실기기 저장소를 건드린다.
    /// loadsInBackground — 앱 시작용. 디코딩을 메인 밖에서 하고, 끝나면 메인에서 한 번에 채운다.
    public init(fileURL: URL? = nil, closures: DayClosures, loadsInBackground: Bool = false) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("days.json")
        self.closures = closures
        self.writer = CoalescingWriter.forFile(self.fileURL)
        writer.flush()
        guard loadsInBackground else { load(); return }
        isLoaded = false
        let url = self.fileURL
        Task.detached(priority: .userInitiated) { [weak self] in
            let loaded = (try? Data(contentsOf: url)).map(Self.decodeMoments) ?? []
            await MainActor.run { self?.finishLoading(loaded) }
        }
    }

    /// 로드 전에 들어온 기록(카메라 등)은 읽은 기록 뒤에 같은 중복 규칙으로 붙인다.
    @MainActor
    private func finishLoading(_ loaded: [Moment]) {
        let early = moments
        var merged = loaded
        for m in early where !merged.contains(where: {
            $0.id == m.id || $0.fileName == m.fileName || (m.originalName != nil && $0.originalName == m.originalName)
        }) { merged.append(m) }
        moments = merged
        isLoaded = true
        if saveDeferred { saveDeferred = false; save() }
        let waiters = loadWaiters
        loadWaiters = []
        waiters.forEach { $0.resume() }
    }

    /// 백그라운드 로드가 끝날 때까지 — 동기화·입양·위젯 맞추기는 이 뒤에 시작해야 빈 목록으로 판단하지 않는다.
    @MainActor
    public func waitUntilLoaded() async {
        guard !isLoaded else { return }
        await withCheckedContinuation { loadWaiters.append($0) }
    }

    public var today: [Moment] { moments(on: Moment.dayKey(for: Date())) }

    public func moments(on dayKey: String) -> [Moment] {
        index.byDay[dayKey] ?? []
    }

    public var dayKeys: [String] { index.keys }

    public var finishedDayKeys: [String] {
        let today = Moment.dayKey(for: Date())
        return dayKeys.filter { isFinished($0, today: today) }
    }

    /// 오늘 이전은 항상, 오늘은 「마무리하기」로 닫혀야 true.
    public func isFinished(_ dayKey: String) -> Bool {
        isFinished(dayKey, today: Moment.dayKey(for: Date()))
    }

    private func isFinished(_ dayKey: String, today: String) -> Bool {
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

    /// 여러 장을 한 번에 — 저장·알림·화면 갱신이 한 번이다. 중복 규칙은 add 와 같고, 넣은 것만 돌려준다.
    @discardableResult
    public func add(contentsOf incoming: [Moment]) -> [Moment] {
        var names = Set(moments.map(\.fileName))
        var originals = Set(moments.compactMap(\.originalName))
        var added: [Moment] = []
        for m in incoming {
            guard !names.contains(m.fileName), !(m.originalName.map(originals.contains) ?? false) else { continue }
            names.insert(m.fileName)
            if let o = m.originalName { originals.insert(o) }
            added.append(m)
        }
        guard !added.isEmpty else { return [] }
        moments.append(contentsOf: added)
        save()
        notify(added.map { .upsert($0.id) })
        return added
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

    public func remove(ids: Set<Moment.ID>) {
        guard !ids.isEmpty else { return }
        let removed = moments.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        moments.removeAll { ids.contains($0.id) }
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

    public static let remoteChunkThreshold = 50
    public static let remoteChunkSize = 40

    /// 큰 묶음은 40건씩 나눠 넣고 사이에 pause 로 화면을 한 번 그리게 한다. deletes 는 마지막 조각에 — upsert 먼저 규칙 그대로.
    @MainActor
    @discardableResult
    public func applyRemoteInChunks(upserts: [Moment], deletes: Set<Moment.ID>,
                                    pause: () async -> Void) async -> [StoreChange] {
        guard upserts.count > Self.remoteChunkThreshold else { return applyRemote(upserts: upserts, deletes: deletes) }
        var push: [StoreChange] = []
        var start = 0
        while start < upserts.count {
            let end = min(start + Self.remoteChunkSize, upserts.count)
            let last = end == upserts.count
            push += applyRemote(upserts: Array(upserts[start..<end]), deletes: last ? deletes : [])
            start = end
            if !last { await pause() }
        }
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
        flush()
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
        moments = Self.decodeMoments(data)
    }

    static func decodeMoments(_ data: Data) -> [Moment] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let text = try c.decode(String.self)
            guard let date = ISODate.parse(text) ?? Self.fractionalDate.date(from: text)
                    ?? Self.wholeSecondDate.date(from: text) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "날짜 형식 아님: \(text)")
            }
            return date
        }
        let decoded = (try? decoder.decode([Moment].self, from: data)) ?? []
        return decoded.map { m in
            var m = m
            if m.labels == nil { m.word = nil }
            return m
        }
    }

    static func encodeDate(_ date: Date) -> String { fractionalDate.string(from: date) }

    /// 밀린 저장을 지금 끝낸다 — 앱이 background 로 갈 때 부른다.
    public func flush() { writer.flush() }

    /// 지금까지의 저장이 디스크에 닿은 뒤 work 를 돌린다(메인을 막지 않는다).
    public func afterSaved(_ work: @escaping @Sendable () -> Void) { writer.then(work) }

    private func save() {
        // 로드 전 저장은 디스크의 전체 기록을 일부로 덮어쓴다 — 로드 끝에 한 번 쓴다.
        guard isLoaded else { saveDeferred = true; return }
        let snapshot = moments
        writer.write { Self.encode(snapshot) }
    }

    private static func encode(_ moments: [Moment]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, e in
            var c = e.singleValueContainer()
            try c.encode(encodeDate(date))
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(moments)
    }
}
