import Foundation
import Observation

@Observable
public final class DayStore {

    @ObservationIgnored private var all: [Moment] = [] {
        didSet { revision &+= 1; changed() }
    }
    @ObservationIgnored private var revision = 0

    // 관찰은 이 값으로만 한다 — 대량 수신 중엔 all 이 조각마다 바뀌어도 화면에는 묶어서 알린다.
    private var published = 0
    @ObservationIgnored private var bulkDepth = 0
    @ObservationIgnored private var unpublished = false
    @ObservationIgnored private var publishTask: Task<Void, Never>?

    /// 대량 수신 중 화면에 알리는 간격.
    public static let bulkPublishInterval: UInt64 = 100_000_000

    public var moments: [Moment] {
        _ = published
        return all
    }

    private func changed() {
        guard bulkDepth > 0 else { published &+= 1; return }
        unpublished = true
        guard publishTask == nil else { return }
        publishTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.bulkPublishInterval)
            guard let self, !Task.isCancelled else { return }
            self.publishTask = nil
            self.publishNow()
        }
    }

    private func publishNow() {
        guard unpublished else { return }
        unpublished = false
        published &+= 1
    }

    private func endBulk() {
        bulkDepth -= 1
        guard bulkDepth == 0 else { return }
        publishTask?.cancel()
        publishTask = nil
        publishNow()
    }

    private struct DayIndex {
        var byDay: [String: [Moment]]
        var keys: [String]
        let zone: String
        var revision: Int
    }
    @ObservationIgnored private var dayIndex: DayIndex?

    /// 하루 안 정렬 — capturedAt 이 같으면 id 로 갈라 패치와 재구축이 늘 같은 순서를 내게 한다.
    private static func dayOrder(_ a: Moment, _ b: Moment) -> Bool {
        a.capturedAt != b.capturedAt ? a.capturedAt < b.capturedAt : a.id.uuidString < b.id.uuidString
    }

    // 캐시가 맞아도 published 를 읽는다 — 안 읽으면 뷰가 이 저장소를 관찰하지 않아 새 기록을 못 본다.
    private var index: DayIndex {
        _ = published
        let zone = Moment.zoneIdentifier
        if let dayIndex, dayIndex.zone == zone, dayIndex.revision == revision { return dayIndex }
        var byDay: [String: [Moment]] = [:]
        for m in all { byDay[m.dayKey, default: []].append(m) }
        // capturedAt 이 같으면 id 로 갈라야 패치와 재구축이 같은 순서를 낸다.
        for key in byDay.keys { byDay[key]?.sort(by: Self.dayOrder) }
        let built = DayIndex(byDay: byDay, keys: byDay.keys.sorted(by: >), zone: zone, revision: revision)
        dayIndex = built
        return built
    }

    /// 바뀐 것만 인덱스에 반영한다 — before 는 바꾸기 전 revision. 그때 인덱스가 최신이 아니었으면 다음에 통째로 다시 만든다.
    private func patchIndex(since before: Int, ops: [IndexOp]) {
        guard !ops.isEmpty else { return }
        guard var idx = dayIndex, idx.revision == before, idx.zone == Moment.zoneIdentifier else { return }
        dayIndex = nil
        var presentBefore: [String: Bool] = [:]
        for op in ops {
            switch op {
            case .remove(let m):
                let key = m.dayKey
                if presentBefore[key] == nil { presentBefore[key] = idx.byDay[key] != nil }
                guard var list = idx.byDay[key], let p = list.firstIndex(of: m) else { return }
                list.remove(at: p)
                idx.byDay[key] = list
            case .insert(let m):
                let key = m.dayKey
                if presentBefore[key] == nil { presentBefore[key] = idx.byDay[key] != nil }
                idx.byDay[key, default: []].append(m)
            }
        }
        var keysChanged = false
        for (key, was) in presentBefore {
            let list = idx.byDay[key] ?? []
            idx.byDay[key] = list.isEmpty ? nil : list.sorted(by: Self.dayOrder)
            if was == list.isEmpty { keysChanged = true }
        }
        if keysChanged { idx.keys = idx.byDay.keys.sorted(by: >) }
        idx.revision = revision
        dayIndex = idx
    }

    /// 테스트 전용 — 고쳐 붙인 인덱스가 처음부터 만든 것과 같은지.
    func indexMatchesRebuild() -> Bool {
        let patched = index
        dayIndex = nil
        let rebuilt = index
        return patched.keys == rebuilt.keys && patched.byDay.mapValues { $0.map(\.id) } == rebuilt.byDay.mapValues { $0.map(\.id) }
    }

    // 조각마다 전체 기록으로 id·cloudID 사전을 새로 만들지 않게 — 마지막 applyRemote 뒤 아무것도 안 바뀌었을 때만 이어 쓴다.
    private struct Lookup {
        var byID: [Moment.ID: Int]
        var byCloud: [String: Int]
        var revision: Int
    }
    @ObservationIgnored private var lookup: Lookup?

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
    public typealias FileReader = @Sendable (URL) throws -> Data
    private let readData: FileReader
    @ObservationIgnored private let writer: CoalescingWriter

    /// days.json 을 다 읽었으면 true. 백그라운드 로드 중엔 빈 화면 안내를 띄우면 안 된다.
    public private(set) var isLoaded = true
    @ObservationIgnored private var loadWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var saveDeferred = false
    @ObservationIgnored private var loadAttempt: Task<Void, Never>?
    @ObservationIgnored private var heldAfterSaved: [@Sendable () -> Void] = []

    public enum LoadIssue: Equatable, Sendable {
        case partial(skipped: Int)
        case unreadable
    }
    /// days.json 을 온전히 못 읽었으면 그 사정. 원본은 corruptBackupURL 로 복사돼 있다.
    public private(set) var loadIssue: LoadIssue?
    public private(set) var corruptBackupURL: URL?

    /// 저장을 거부하는 중인지 — 원본 백업이 없거나, 통째로 못 읽었는데 새 기록도 없을 때.
    public var isSaveBlocked: Bool {
        guard let loadIssue else { return false }
        guard corruptBackupURL != nil else { return true }
        return loadIssue == .unreadable && moments.isEmpty
    }

    // closures 는 기본값을 주지 않는다 — 묵시적으로 .standard 를 공유하면 테스트가 실기기 저장소를 건드린다.
    /// loadsInBackground — 앱 시작용. 디코딩을 메인 밖에서 하고, 끝나면 메인에서 한 번에 채운다.
    /// 파일이 있는데 못 읽으면(첫 잠금 해제 전 등) 로드 전 상태로 남는다 — retryLoadIfNeeded 로 다시 읽는다.
    public init(fileURL: URL? = nil, closures: DayClosures, loadsInBackground: Bool = false,
                readData: @escaping FileReader = { try Data(contentsOf: $0) }) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("days.json")
        self.closures = closures
        self.readData = readData
        self.writer = CoalescingWriter.forFile(self.fileURL)
        writer.flush()
        guard loadsInBackground else { load(); return }
        isLoaded = false
        loadAttempt = startLoadAttempt()
    }

    private func startLoadAttempt() -> Task<Void, Never> {
        let url = fileURL, read = readData
        return Task.detached(priority: .userInitiated) { [weak self] in
            guard let loaded = Self.readFile(url, read: read) else { return }
            await MainActor.run { self?.finishLoading(loaded) }
        }
    }

    /// 아직 못 읽었으면 다시 읽는다 — 보호 데이터가 풀렸을 때·앱이 active 가 될 때 앱이 부른다.
    @MainActor
    public func retryLoadIfNeeded() async {
        if let running = loadAttempt { await running.value }
        guard !isLoaded else { return }
        let attempt = startLoadAttempt()
        loadAttempt = attempt
        await attempt.value
    }

    /// 로드 전에 들어온 기록(카메라 등)은 읽은 기록 뒤에 같은 중복 규칙으로 붙인다.
    @MainActor
    private func finishLoading(_ loaded: Loaded) {
        // 재시도가 겹쳐 두 번 읽혀도 두 번째가 그 사이 바뀐 기록을 디스크 값으로 되돌리지 않게.
        guard !isLoaded else { return }
        adoptIssue(loaded)
        let early = moments
        var merged = loaded.moments
        for m in early where !merged.contains(where: {
            $0.id == m.id || $0.fileName == m.fileName || (m.originalName != nil && $0.originalName == m.originalName)
        }) { merged.append(m) }
        all = merged
        isLoaded = true
        if saveDeferred { saveDeferred = false; save() }
        let held = heldAfterSaved
        heldAfterSaved = []
        if !isSaveBlocked { held.forEach { writer.then($0) } }
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

    public var finishedDayKeys: [String] { finished().days }

    private struct FinishedKey: Equatable {
        let revision: Int, zone: String, today: String, todayClosed: Date?
    }
    @ObservationIgnored private var finishedCache: (key: FinishedKey, days: [String])?
    @ObservationIgnored private var homeCache: (key: FinishedKey, giftFloor: String?, summary: HomeSummary)?

    private func finished() -> (key: FinishedKey, days: [String]) {
        let idx = index
        let today = Moment.dayKey(for: Date())
        let key = FinishedKey(revision: idx.revision, zone: idx.zone, today: today, todayClosed: closures.closedAt(today))
        if let finishedCache, finishedCache.key == key { return finishedCache }
        let built = (key, idx.keys.filter { isFinished($0, today: today) })
        finishedCache = built
        return built
    }

    /// 홈 목록 파생값 — 기록·오늘·마무리·받은 날이 그대로면 저번 것을 돌려준다.
    public func home(gifts: GiftLog) -> HomeSummary {
        let (key, days) = finished()
        let floor = gifts.lastGiftedDayKey
        if let homeCache, homeCache.key == key, homeCache.giftFloor == floor { return homeCache.summary }
        let summary = HomeSummary.make(days: days, isGifted: gifts.isGifted, today: key.today)
        homeCache = (key, floor, summary)
        return summary
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
        let before = revision
        all.append(moment)
        patchIndex(since: before, ops: [.insert(moment)])
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
        let before = revision
        all.append(contentsOf: added)
        patchIndex(since: before, ops: added.map { .insert($0) })
        save()
        notify(added.map { .upsert($0.id) })
        return added
    }

    public func assignWord(_ id: Moment.ID, _ word: PhotoWord) {
        guard let i = all.firstIndex(where: { $0.id == id }), all[i].word == nil else { return }
        all[i].word = word
        save()
        notify([.upsert(id)])
    }

    /// 방금 찍은 사진에 위치가 늦게 도착했을 때 — 이미 있으면 덮지 않는다.
    public func setPlace(_ id: Moment.ID, _ place: Place) {
        guard let i = all.firstIndex(where: { $0.id == id }), all[i].place == nil else { return }
        all[i].place = place
        save()
        notify([.upsert(id)])
    }

    public func setPlaceWeather(_ id: Moment.ID, _ weather: PlaceWeather) {
        guard let i = all.firstIndex(where: { $0.id == id }), var place = all[i].place, place.weather == nil else { return }
        place.weather = weather
        all[i].place = place
        save()
        notify([.upsert(id)])
    }

    public func setPlaceName(_ id: Moment.ID, _ name: String) {
        guard let i = all.firstIndex(where: { $0.id == id }), var place = all[i].place, place.name == nil else { return }
        place.name = name
        all[i].place = place
        save()
        notify([.upsert(id)])
    }

    public func setLabels(_ id: Moment.ID, _ labels: [String]) {
        guard let i = all.firstIndex(where: { $0.id == id }), all[i].labels == nil else { return }
        all[i].labels = labels
        save()
        notify([.upsert(id)])
    }

    /// 단어와 라벨을 한 번에 — 처음 붙일 때도, 틀린 단어를 바꿀 때도. 빈 단어로 먼저 올라가면 옛 단어를 든 기기가 되올린다.
    /// stale 이 지금 단어와 다르면(고르는 사이 다른 기기의 단어가 왔으면) 덮지 않는다.
    @discardableResult
    public func stampWord(_ id: Moment.ID, _ word: PhotoWord, labels: [String], replacing stale: PhotoWord?) -> Bool {
        guard let i = all.firstIndex(where: { $0.id == id }), all[i].word == stale, all[i].word != word else { return false }
        all[i].word = word
        all[i].labels = labels
        save()
        notify([.upsert(id)])
        return true
    }

    /// 「이 단어는 아니에요」 — 사진마다 한 번(WordRejections 가 지킨다). 그 밖엔 단어를 바꾸지 않는다.
    public func replaceWord(_ id: Moment.ID, _ word: PhotoWord) {
        guard let i = all.firstIndex(where: { $0.id == id }), all[i].word != nil, all[i].word != word else { return }
        all[i].word = word
        save()
        notify([.upsert(id)])
    }

    /// 단어가 아직 없을 때만 라벨을 새로 본 것으로 바꾼다 — 단어가 붙은 뒤엔 라벨도 고정이다.
    public func refreshLabels(_ id: Moment.ID, _ labels: [String]) {
        guard let i = all.firstIndex(where: { $0.id == id }), all[i].word == nil, all[i].labels != labels else { return }
        all[i].labels = labels
        save()
        notify([.upsert(id)])
    }

    public func moment(_ id: Moment.ID) -> Moment? { moments.first { $0.id == id } }

    public func pebbleName(on dayKey: String) -> String? {
        PebbleNaming.name(for: moments.filter { $0.dayKey == dayKey })?.name
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

    @ObservationIgnored private var assetIDCache: (revision: Int, ids: Set<String>)?

    /// 사진첩 격자가 칸마다 부른다 — 칸마다 전체 기록을 훑지 않게 세대마다 한 번 모은다.
    public func containsAsset(_ id: String) -> Bool {
        _ = published
        if let assetIDCache, assetIDCache.revision == revision { return assetIDCache.ids.contains(id) }
        let ids = Set(all.compactMap(\.assetID))
        assetIDCache = (revision, ids)
        return ids.contains(id)
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
        guard let i = all.firstIndex(where: { $0.id == id }), all[i].assetID == nil else { return false }
        all[i] = reassetted(all[i], assetID: assetID)
        save()
        return true
    }

    /// 에셋이 사라져 남은 파일을 사진 앱에 새로 저장한 기록 — assetID 가 아직 `oldAssetID` 일 때만 바꾼다.
    /// 옛 cloudID 는 사라진 사진 것이라 비운다(새 cloudID 는 호출부가 매핑으로 붙인다). true 일 때만 파일을 지워도 된다.
    /// 비운 cloudID 를 올린다 — 안 올리면 병합(remote.cloudID ?? local)이 서버의 옛 cloudID 를 되살린다.
    @discardableResult
    public func readopt(_ id: Moment.ID, from oldAssetID: String, to newAssetID: String) -> Bool {
        guard oldAssetID != newAssetID,
              let i = all.firstIndex(where: { $0.id == id }), all[i].assetID == oldAssetID else { return false }
        var m = reassetted(all[i], assetID: newAssetID)
        m.cloudID = nil
        all[i] = m
        ShotImage.generation.bump(assetID: newAssetID)
        save()
        notify([.upsert(id)])
        return true
    }

    /// 받은 기록(assetID 없음)에 이 기기 사진을 다시 찾아 붙인다. adopt 와 달리 알리지 않는다 — assetID 는 이 기기 전용.
    public func resolveAsset(_ id: Moment.ID, assetID: String) {
        resolveAssets([(id, assetID)])
    }

    public func resolveAssets(_ pairs: [(Moment.ID, String)]) {
        let index = Dictionary(all.indices.map { (all[$0].id, $0) }, uniquingKeysWith: { a, _ in a })
        let before = revision
        var ops: [IndexOp] = []
        for (id, assetID) in pairs {
            guard let i = index[id], all[i].assetID == nil else { continue }
            let resolved = reassetted(all[i], assetID: assetID)
            ops.append(.remove(all[i])); ops.append(.insert(resolved))
            all[i] = resolved
            // 방금 assetID 가 붙었다 — 이 자산을 그리던 칸(색 면으로 남아 있었을 수 있는)이 다시 요청하도록.
            ShotImage.generation.bump(assetID: assetID)
        }
        guard !ops.isEmpty else { return }
        patchIndex(since: before, ops: ops)
        save()
    }

    /// 복원 등으로 바뀐 에셋 ID 로 갈아 끼운다. 알리지 않는다 — assetID 는 이 기기 전용.
    public func reassignAssets(_ pairs: [(Moment.ID, String)]) {
        let index = Dictionary(all.indices.map { (all[$0].id, $0) }, uniquingKeysWith: { a, _ in a })
        var changed = false
        for (id, assetID) in pairs {
            guard let i = index[id], let old = all[i].assetID, old != assetID else { continue }
            all[i] = reassetted(all[i], assetID: assetID)
            changed = true
            ShotImage.generation.bump(assetID: assetID)
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
        all.removeAll { $0.assetID.map(assetIDs.contains) ?? false }
        save()
        notify(removed.map { .delete($0.id) })
    }

    public func remove(ids: Set<Moment.ID>) {
        guard !ids.isEmpty else { return }
        let removed = moments.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        all.removeAll { ids.contains($0.id) }
        save()
        notify(removed.map { .delete($0.id) })
    }

    /// 사진 보기의 「몽돌에서 빼기」 — 기록만 지운다(사진 앱 사진은 그대로). 지운 기록은 iCloud 로 다른 기기에도 번진다.
    /// 알아서 담는 길이 되살리지 않게 RemovedPhotos 에 적고, 이 기기에 남은 사본 파일은 돌려준 Task 가 지운다.
    @MainActor
    @discardableResult
    public func takeOut(_ id: Moment.ID, noting defaults: UserDefaults = .standard) -> Task<Void, Never>? {
        guard let m = moment(id) else { return nil }
        RemovedPhotos.note(m, defaults: defaults)
        remove(ids: [id])
        return removeLeftoverFiles(of: [m])
    }

    /// 지운 기록의 사본 파일 — 남은 기록이 아무도 안 쓰는 것만, 지운 게 디스크에 닿은 뒤에 지운다.
    @MainActor
    @discardableResult
    public func removeLeftoverFiles(of removed: [Moment]) -> Task<Void, Never>? {
        let names = Set(removed.map(\.fileName).filter { !$0.hasPrefix("asset-") && !$0.hasPrefix("remote-") })
        guard !names.isEmpty else { return nil }
        let free = { names.subtracting(self.moments.map(\.fileName)) }
        return Task { @MainActor in
            // 삭제가 디스크에 닿기 전에 지우면 kill 뒤 되살아난 기록이 빈 파일을 가리킨다.
            guard !free().isEmpty, await flushAfterLoad() else { return }
            let files = free()
            await Task.detached(priority: .utility) {
                for name in files { try? FileManager.default.removeItem(at: ShotImage.url(name)) }
            }.value
        }
    }

    public func setCloudID(_ id: Moment.ID, _ cloudID: String) {
        setCloudIDs([(id, cloudID)])
    }

    /// 같은 cloudID 기록이 이미 있으면 combine 으로 합친다. 저장·알림은 한 번.
    public func setCloudIDs(_ pairs: [(Moment.ID, String)]) {
        var index: [Moment.ID: Int] = [:], byCloud: [String: Int] = [:]
        for (i, m) in all.enumerated() {
            index[m.id] = i
            if let c = m.cloudID { byCloud[c] = i }
        }
        var dropped = Set<Int>()
        var changes: [StoreChange] = []
        for (id, cloudID) in pairs {
            guard let i = index[id], !dropped.contains(i), all[i].cloudID == nil else { continue }
            all[i].cloudID = cloudID
            guard let j = byCloud[cloudID], j != i, !dropped.contains(j) else {
                byCloud[cloudID] = i
                changes.append(.upsert(id))
                continue
            }
            let combined = MomentMerge.combine(all[i], all[j])
            let (keep, drop) = combined.id == all[i].id ? (i, j) : (j, i)
            // i 가 남으면 서버의 i 에는 cloudID 가 없다 — 항상 올린다.
            let needsUpsert = keep == i || !MomentMerge.syncedEqual(combined, all[j])
            changes.append(.delete(all[drop].id))
            if needsUpsert { changes.append(.upsert(combined.id)) }
            all[keep] = combined
            dropped.insert(drop)
            byCloud[cloudID] = keep
        }
        guard !changes.isEmpty else { return }
        let droppedIDs = Set(dropped.map { all[$0].id })
        all = all.enumerated().filter { !dropped.contains($0.offset) }.map(\.element)
        changes.removeAll { if case .upsert(let id) = $0 { return droppedIDs.contains(id) } else { return false } }
        save()
        notify(changes)
    }

    /// upserts 먼저, deletes 나중 — 다른 기기의 delete(a)+upsert(b)(같은 cloudID)를 받을 때 a 의 사진 연결을 b 로 넘기려고.
    @discardableResult
    public func applyRemote(upserts: [Moment], deletes: Set<Moment.ID>) -> [StoreChange] {
        let (push, changed) = applyRemoteCore(upserts: upserts, deletes: deletes)
        if changed { save() }
        return push
    }

    private enum IndexOp {
        case remove(Moment)
        case insert(Moment)
    }

    private func applyRemoteCore(upserts: [Moment], deletes: Set<Moment.ID>) -> ([StoreChange], Bool) {
        let before = revision
        var push: [StoreChange] = []
        var changed = false
        var ops: [IndexOp] = []
        var index: [Moment.ID: Int], byCloud: [String: Int]
        if let lookup, lookup.revision == revision {
            (index, byCloud) = (lookup.byID, lookup.byCloud)
        } else {
            index = [:]; byCloud = [:]
            index.reserveCapacity(all.count + upserts.count)
            for (i, m) in all.enumerated() {
                index[m.id] = i
                if let c = m.cloudID { byCloud[c] = i }
            }
        }
        lookup = nil
        for incoming in upserts {
            let remote = incoming.withDeviceFields(
                fileName: Moment.receivedFileName(cloudID: incoming.cloudID, id: incoming.id),
                assetID: nil, originalName: nil)
            // 이어 쓴 사전은 옛 자리를 가리킬 수 있다 — 가리킨 기록이 정말 그 id·cloudID 일 때만 믿는다.
            if let i = index[remote.id], all[i].id == remote.id {
                let merged = MomentMerge.merge(local: all[i], remote: remote)
                if merged != all[i] {
                    ops.append(.remove(all[i])); ops.append(.insert(merged))
                    all[i] = merged; changed = true
                }
                if let c = merged.cloudID { byCloud[c] = i }
                if !MomentMerge.syncedEqual(merged, remote) { push.append(.upsert(merged.id)) }
            } else if let cid = remote.cloudID, let j = byCloud[cid], all[j].cloudID == cid {
                let local = all[j]
                let combined = MomentMerge.combine(local, remote)
                let remoteWins = combined.id == remote.id
                push.append(.delete(remoteWins ? local.id : remote.id))
                if !MomentMerge.syncedEqual(combined, remoteWins ? remote : local) { push.append(.upsert(combined.id)) }
                if combined != local {
                    ops.append(.remove(local)); ops.append(.insert(combined))
                    all[j] = combined
                    index[local.id] = nil
                    index[combined.id] = j
                    changed = true
                }
            } else {
                all.append(remote)
                ops.append(.insert(remote))
                index[remote.id] = all.count - 1
                if let c = remote.cloudID { byCloud[c] = all.count - 1 }
                changed = true
            }
        }
        var shifted = false
        if !deletes.isEmpty {
            for i in all.indices where deletes.contains(all[i].id) {
                let doomed = all[i]
                guard doomed.assetID != nil, let cid = doomed.cloudID,
                      let k = all.indices.first(where: {
                          $0 != i && all[$0].cloudID == cid && all[$0].assetID == nil
                              && !deletes.contains(all[$0].id)
                      }) else { continue }
                let handed = all[k].withDeviceFields(fileName: doomed.fileName, assetID: doomed.assetID,
                                                     originalName: doomed.originalName)
                ops.append(.remove(all[k])); ops.append(.insert(handed))
                all[k] = handed
            }
            let doomed = all.filter { deletes.contains($0.id) }
            if !doomed.isEmpty {
                ops += doomed.map { .remove($0) }
                all.removeAll { deletes.contains($0.id) }
                changed = true
                shifted = true
            }
        }
        if !shifted { lookup = Lookup(byID: index, byCloud: byCloud, revision: revision) }
        patchIndex(since: before, ops: ops)
        return (push, changed)
    }

    public static let remoteChunkThreshold = 50
    public static let remoteChunkSize = 40

    /// 큰 묶음은 40건씩 나눠 넣고 사이에 pause 로 화면을 한 번 그리게 한다. deletes 는 마지막 조각에 — upsert 먼저 규칙 그대로.
    /// excluding 은 조각마다 다시 읽는다 — 쉬는 사이 이 기기에서 지운 기록을 뒤 조각이 되살리지 않게.
    /// 도는 동안 화면 알림은 bulkPublishInterval 마다 한 번, days.json 저장은 끝에 한 번이다.
    @MainActor
    @discardableResult
    public func applyRemoteInChunks(upserts: [Moment], deletes: Set<Moment.ID>,
                                    excluding: () -> Set<Moment.ID> = { [] },
                                    pause: () async -> Void) async -> [StoreChange] {
        guard upserts.count > Self.remoteChunkThreshold else {
            let skip = excluding()
            return applyRemote(upserts: skip.isEmpty ? upserts : upserts.filter { !skip.contains($0.id) }, deletes: deletes)
        }
        bulkDepth += 1
        defer { endBulk() }
        var push: [StoreChange] = []
        var changed = false
        var start = 0
        while start < upserts.count {
            let end = min(start + Self.remoteChunkSize, upserts.count)
            let last = end == upserts.count
            let skip = excluding()
            let chunk = skip.isEmpty ? Array(upserts[start..<end]) : upserts[start..<end].filter { !skip.contains($0.id) }
            let (p, c) = applyRemoteCore(upserts: chunk, deletes: last ? deletes : [])
            push += p
            changed = changed || c
            start = end
            if !last { await pause() }
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
        loadIssue = nil
        all = []
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
        guard let loaded = Self.readFile(fileURL, read: readData) else { isLoaded = false; return }
        adoptIssue(loaded)
        all = loaded.moments
    }

    private func adoptIssue(_ loaded: Loaded) {
        loadIssue = loaded.issue
        corruptBackupURL = loaded.backup
    }

    struct Loaded: Sendable {
        var moments: [Moment] = []
        var issue: LoadIssue?
        var backup: URL?
    }

    /// 읽다 걸린 게 있으면 어떤 저장보다 먼저 원본을 옆에 복사해 둔다.
    /// nil — 파일은 있는데 아직 못 읽음(첫 잠금 해제 전 파일 보호·IO 오류). 손상이 아니라 나중에 다시 읽는다.
    static func readFile(_ url: URL, read: FileReader = { try Data(contentsOf: $0) }) -> Loaded? {
        guard let data = try? read(url) else {
            // 있는데 못 읽은 걸 없는 것으로 보고 새로 쓰면 전부 날아간다.
            return FileManager.default.fileExists(atPath: url.path) ? nil : Loaded()
        }
        guard !data.isEmpty else { return Loaded() }
        let decoded = decodeReport(data)
        guard let issue = decoded.issue else { return Loaded(moments: decoded.moments) }
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        let backup = url.deletingLastPathComponent().appendingPathComponent("\(url.lastPathComponent).corrupt-\(stamp)")
        let copied = (try? data.write(to: backup, options: .atomic)) != nil
        return Loaded(moments: decoded.moments, issue: issue, backup: copied ? backup : nil)
    }

    static func decodeMoments(_ data: Data) -> [Moment] { decodeReport(data).moments }

    private struct Failable<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    static func decodeReport(_ data: Data) -> (moments: [Moment], issue: LoadIssue?) {
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
        guard let items = try? decoder.decode([Failable<Moment>].self, from: data) else { return ([], .unreadable) }
        let decoded = items.compactMap(\.value)
        let skipped = items.count - decoded.count
        let moments = decoded.map { m in
            var m = m
            if m.labels == nil { m.word = nil }
            return m
        }
        return (moments, skipped > 0 ? .partial(skipped: skipped) : nil)
    }

    static func encodeDate(_ date: Date) -> String { fractionalDate.string(from: date) }

    /// 밀린 저장을 지금 끝낸다 — 앱이 background 로 갈 때 부른다. false 면 마지막 쓰기가 실패했다.
    @discardableResult
    public func flush() -> Bool { writer.flush() }

    /// 로드 전이면 로드(미뤄 둔 저장)까지 기다린 뒤 flush — 파일 삭제·세션 무효화처럼 되돌릴 수 없는 일 직전에.
    /// true 일 때만 지금 기록이 디스크에 있다(쓰기 실패·저장 막힘이면 false) — 되돌릴 수 없는 일은 true 일 때만.
    @MainActor
    @discardableResult
    public func flushAfterLoad() async -> Bool {
        await waitUntilLoaded()
        let blocked = isSaveBlocked
        let written = await writer.flushed()
        return written && !blocked && !isSaveBlocked
    }

    /// 지금까지의 저장이 디스크에 닿은 뒤 work 를 돌린다(메인을 막지 않는다).
    /// 로드 전이면 미뤄 둔 저장 뒤로 넘기고, 저장이 막혀 있으면 버린다 — 기록이 디스크에 없는데 뒤따르는 일(동기화 토큰)만 남지 않게.
    public func afterSaved(_ work: @escaping @Sendable () -> Void) {
        guard isLoaded else { heldAfterSaved.append(work); return }
        guard !isSaveBlocked else { return }
        writer.then(work)
    }

    private func save() {
        // 로드 전 저장은 디스크의 전체 기록을 일부로 덮어쓴다 — 로드 끝에 한 번 쓴다.
        guard isLoaded else { saveDeferred = true; return }
        // 못 읽은 원본을 빈(또는 일부) 목록으로 덮으면 되돌릴 길이 없다.
        guard !isSaveBlocked else { return }
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
