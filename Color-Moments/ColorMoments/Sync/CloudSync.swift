import CloudKit
import os

@MainActor
final class CloudSync: CKSyncEngineDelegate {

    private let store: DayStore
    private let closures: DayClosures
    private let gifts: GiftLog
    private var engine: CKSyncEngine?
    private let log = Logger(subsystem: "com.itlearning.colormoments", category: "sync")

    static let containerID = "iCloud.com.itlearning.colormoments"
    private let stateURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("sync-state.json")
    private let systemFields = SystemFieldsCache(fileURL: FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("sync-records.json"))

    init(store: DayStore, closures: DayClosures, gifts: GiftLog) {
        self.store = store
        self.closures = closures
        self.gifts = gifts
    }

    func start() {
        guard engine == nil else { return }
        let state = (try? Data(contentsOf: stateURL))
            .flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
        let db = CKContainer(identifier: Self.containerID).privateCloudDatabase
        engine = CKSyncEngine(CKSyncEngine.Configuration(database: db, stateSerialization: state, delegate: self))

        store.onLocalChange = { [weak self] changes in self?.enqueue(changes) }
        closures.onLocalChange = { [weak self] key in self?.enqueueDay(key) }
        gifts.onLocalChange = { [weak self] key in self?.enqueueDay(key) }
        PebbleNaming.stamps.onLocalChange = { [weak self] key in self?.enqueueDay(key) }

        if state == nil { enqueueEverything() }
    }

    /// 밀린 시스템 필드 쓰기를 지금 끝낸다 — 앱이 background 로 갈 때.
    func flush() { systemFields.flush() }

    // MARK: 보낼 것

    private func add(_ changes: [CKSyncEngine.PendingRecordZoneChange]) {
        guard let engine, !changes.isEmpty else { return }
        let pending = Set(engine.state.pendingRecordZoneChanges)
        var seen = Set<CKSyncEngine.PendingRecordZoneChange>()
        let fresh = changes.filter { !pending.contains($0) && seen.insert($0).inserted }
        if !fresh.isEmpty { engine.state.add(pendingRecordZoneChanges: fresh) }
    }

    private func enqueue(_ changes: [StoreChange]) {
        add(changes.map {
            switch $0 {
            case .upsert(let id): .saveRecord(SyncRecords.recordID(moment: id))
            case .delete(let id): .deleteRecord(SyncRecords.recordID(moment: id))
            }
        })
    }

    private func enqueueDay(_ key: String) {
        add([.saveRecord(SyncRecords.recordID(day: key))])
    }

    private func saveZone() {
        engine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: SyncRecords.zoneID))])
    }

    /// 처음 켤 때·로그인·새 계정 — 이 기기 기록을 전부 올린다. 서버에 이미 있는 기록은 충돌로 돌아와 합쳐진다.
    private func enqueueEverything() {
        saveZone()
        enqueue(store.moments.map { .upsert($0.id) })
        let keys = Set(store.dayKeys).union(closures.closedDays.keys).union(gifts.giftedDayKeys)
            .union(PebbleNaming.stamps.names.keys)
        for key in keys.sorted() where closures.closedAt(key) != nil || gifts.isGifted(key) { enqueueDay(key) }
    }

    private func dayState(_ key: String) -> SyncRecords.DayState {
        SyncRecords.DayState(dayKey: key, closedAt: closures.closedAt(key), gifted: gifts.isGifted(key),
                             pebbleName: PebbleNaming.stamps.name(on: key))
    }

    private func record(for id: CKRecord.ID) -> CKRecord? {
        guard let ref = SyncRecords.ref(id) else { return nil }
        switch ref {
        case .moment(let uuid):
            // nil 이면 엔진이 이 저장 요청을 버린다 — 이미 로컬에서 지운 기록이라 정상.
            guard let m = store.moment(uuid) else { return nil }
            let r = systemFields.record(id, type: SyncRecords.momentType)
            SyncRecords.fill(r, with: m)
            return r
        case .day(let key):
            let r = systemFields.record(id, type: SyncRecords.dayType)
            SyncRecords.fill(r, with: dayState(key))
            return r
        }
    }

    private func forget(_ id: CKRecord.ID) { systemFields.forget(id) }

    private func persistSystemFields() { systemFields.persist() }

    // MARK: 받은 것

    private func apply(modified: [CKRecord], deleted: [CKRecord.ID]) async {
        let current = engine
        let decoded = modified.isEmpty ? SyncRecords.Decoded()
            : await Task.detached(priority: .userInitiated) { SyncRecords.decode(modified) }.value
        // 기다리는 사이 계정이 바뀌었으면 버린다 — 새 엔진이 처음부터 다시 받는다.
        guard engine === current else { return }
        // 이 기기에서 지우고 아직 못 올린 기록을 받은 변경으로 되살리지 않는다.
        let pendingDeletes = Set((engine?.state.pendingRecordZoneChanges ?? []).compactMap {
            if case .deleteRecord(let id) = $0 { id.recordName } else { nil }
        })
        for (name, data) in decoded.archived { systemFields.remember(data, for: name) }
        let upserts = decoded.moments.filter { !pendingDeletes.contains($0.recordName) }.map(\.moment)
        var dayChanged = false
        for (name, d) in decoded.days where !pendingDeletes.contains(name) {
            dayChanged = applyDay(d) || dayChanged
        }
        var deletes = Set<UUID>()
        for id in deleted {
            forget(id)
            if case .moment(let uuid) = SyncRecords.ref(id) { deletes.insert(uuid) }
        }
        let (push, _) = await Self.applyFetched(upserts: upserts, deletes: deletes, to: store,
                                                excluding: { [weak self] in self?.pendingMomentDeletes() ?? [] },
                                                pause: FramePause.next)
        guard engine === current else { return }
        enqueue(push)
        persistSystemFields()
        if !upserts.isEmpty { CloudIDMapper.resolveAfterReceiving(store: store) }
        if dayChanged || !upserts.isEmpty || !deletes.isEmpty { refreshSurfaces() }
    }

    private func pendingMomentDeletes() -> Set<UUID> {
        Set((engine?.state.pendingRecordZoneChanges ?? []).compactMap {
            guard case .deleteRecord(let id) = $0, case .moment(let uuid) = SyncRecords.ref(id) else { return nil }
            return uuid
        })
    }

    /// 받은 변경을 넣는다. 받은 삭제는 다른 기기가 실제로 지운 것 — 뺀 사진을 이 기기의 ♥ 담기가 다시 담으면
    /// 그 기기로 되살아 돌아가니 적어 두고, 이 기기에만 있던 사본 파일은 가리킬 기록이 없으니 지운다.
    @discardableResult
    static func applyFetched(upserts: [Moment], deletes: Set<Moment.ID>, to store: DayStore,
                             excluding: () -> Set<Moment.ID>, pause: () async -> Void,
                             now: Date = Date(), defaults: UserDefaults = .standard)
        async -> (push: [StoreChange], cleanup: Task<Void, Never>?) {
        let leaving = deletes.isEmpty ? [] : store.moments.filter { deletes.contains($0.id) }
        let push = await store.applyRemoteInChunks(upserts: upserts, deletes: deletes, excluding: excluding, pause: pause)
        guard !leaving.isEmpty else { return (push, nil) }
        RemovedPhotos.noteGone(leaving, remaining: store.moments, now: now, defaults: defaults)
        return (push, store.removeLeftoverFiles(of: leaving))
    }

    /// 올리다 받은 「서버에 없음」 — 다른 기기가 지웠을 수도, iCloud 설정에서 몽돌 데이터를 지운 뒤 존이 다시 생겼을 수도 있다.
    /// 기록은 다시 올리면 되살아나니 지우지만, 이 기기에만 있던 원본 파일은 남긴다(icloud-sync §8 「로컬은 둔다」).
    static func dropUnknown(_ id: Moment.ID, from store: DayStore, now: Date = Date(), defaults: UserDefaults = .standard) {
        guard let gone = store.moment(id) else { return }
        store.applyRemote(upserts: [], deletes: [id])
        // 다른 기기가 뺀 사진이면 받은 삭제가 뒤에 와도 지울 기록이 없어 못 적는다 — 여기서 적는다.
        RemovedPhotos.noteGone([gone], remaining: store.moments, now: now, defaults: defaults)
    }

    // 다른 기기에서 받음·닫힘·사진이 들어오면 이 기기의 예약 알림·위젯도 맞춘다 — 안 그러면 이미 받은 날 알림이 울린다.
    private func refreshSurfaces() {
        HomeWidget.scheduleSync(store: store, closures: closures, gifts: gifts)
    }

    /// 이 기기 상태가 바뀌었으면 true.
    private func applyDay(_ d: SyncRecords.DayState) -> Bool {
        let before = dayState(d.dayKey)
        if let at = d.closedAt { closures.applyRemote(dayKey: d.dayKey, closedAt: at) }
        if d.gifted { gifts.applyRemote(gifted: d.dayKey) }
        if let name = d.pebbleName { PebbleNaming.stamps.applyRemote(dayKey: d.dayKey, name: name) }
        // 이 기기가 더 이른 마무리나 받은 증정, 앞선 이름 도장을 알고 있으면 다시 올린다.
        let mine = dayState(d.dayKey)
        if mine.gifted != d.gifted || !Self.sameInstant(mine.closedAt, d.closedAt) || mine.pebbleName != d.pebbleName {
            enqueueDay(d.dayKey)
        }
        return mine.gifted != before.gifted || !Self.sameInstant(mine.closedAt, before.closedAt) || mine.pebbleName != before.pebbleName
    }

    // CloudKit 은 Date 를 밀리초로 자른다 — 정확히 같다로 비교하면 같은 마무리를 끝없이 다시 올린다.
    private static func sameInstant(_ a: Date?, _ b: Date?) -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        return abs(a.timeIntervalSince(b)) < 0.001
    }

    private func resetForAccountChange() {
        // 로컬 기록은 절대 지우지 않는다 — 동기화 상태만 버리고 다음 계정에 다시 올린다.
        // 밀린 상태 쓰기가 지운 뒤에 옛 토큰을 되살리지 않게 — 기록 큐 → 시스템 필드 큐 순으로 비운 뒤 지운다.
        store.flush()
        systemFields.removeAll()
        persistSystemFields()
        systemFields.flush()
        try? FileManager.default.removeItem(at: stateURL)
        engine = nil
        start()
    }

    // MARK: CKSyncEngineDelegate

    // 받은 묶음 적용이 메인 밖 변환·조각 사이에서 쉬는 동안 다음 이벤트(특히 상태 저장)가 끼어들면
    // 토큰이 기록보다 먼저 디스크에 남는다 — 이벤트는 이 꼬리에 줄 세워 하나씩 끝낸다.
    private var eventTail: Task<Void, Never>?

    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await serially(event, from: syncEngine)
    }

    private func serially(_ event: CKSyncEngine.Event, from syncEngine: CKSyncEngine) async {
        let previous = eventTail
        let task = Task { @MainActor in
            await previous?.value
            await self.handle(event, from: syncEngine)
        }
        eventTail = task
        await task.value
    }

    private func handle(_ event: CKSyncEngine.Event, from syncEngine: CKSyncEngine) async {
        // 계정이 바뀌어 새 엔진으로 갈아탄 뒤 옛 엔진이 늦게 보낸 이벤트 — 버린 상태를 되살리지 않게 무시한다.
        guard syncEngine === engine else { return }
        switch event {
        case .stateUpdate(let e):
            guard let data = try? JSONEncoder().encode(e.stateSerialization) else { break }
            // 토큰이 받은 기록보다 먼저 디스크에 남으면 kill 뒤 그 기록을 다시 받지 못한다 — 기록·시스템 필드 쓰기 뒤에 쓴다.
            let url = stateURL, fields = systemFields.fileWriter
            store.afterSaved { fields.then { try? data.write(to: url, options: .atomic) } }

        case .accountChange(let e):
            switch e.changeType {
            case .signIn:
                enqueueEverything()
            case .signOut, .switchAccounts:
                resetForAccountChange()
            @unknown default:
                break
            }

        case .fetchedDatabaseChanges(let e):
            guard let gone = e.deletions.first(where: { $0.zoneID == SyncRecords.zoneID }) else { break }
            systemFields.removeAll()
            persistSystemFields()
            if gone.reason == .encryptedDataReset {
                // 기기 암호 재설정 등으로 서버가 존을 비웠다 — 사용자가 지운 게 아니라 다시 올린다.
                enqueueEverything()
            } else {
                // 사용자가 iCloud 설정에서 몽돌 데이터를 지웠다 — 로컬은 두고, 쌓인 것도 다시 올리지 않는다.
                // 그 뒤 새로 생긴 기록만 zoneNotFound 경로로 존을 다시 만들어 올린다(지운 옛 기록은 되살리지 않는다).
                engine?.state.remove(pendingRecordZoneChanges: engine?.state.pendingRecordZoneChanges
                    .filter { $0.zoneID == SyncRecords.zoneID } ?? [])
            }

        case .fetchedRecordZoneChanges(let e):
            await apply(modified: e.modifications.map(\.record), deleted: e.deletions.map(\.recordID))

        case .sentDatabaseChanges(let e):
            for f in e.failedZoneSaves {
                log.error("zone save failed: \(f.error.localizedDescription, privacy: .public)")
            }

        case .sentRecordZoneChanges(let e):
            let saved = e.savedRecords
            let archived = saved.isEmpty ? [] : await Task.detached(priority: .utility) {
                saved.map { ($0.recordID.recordName, SystemFieldsCache.archive($0)) }
            }.value
            guard syncEngine === engine else { return }
            for (name, data) in archived { systemFields.remember(data, for: name) }
            e.deletedRecordIDs.forEach(forget)
            for failure in e.failedRecordSaves {
                let id = failure.record.recordID
                switch failure.error.code {
                case .serverRecordChanged:
                    guard let server = failure.error.serverRecord else { break }
                    // 합친 결과가 서버와 다를 때만 apply 가 다시 올린다 — 무조건 다시 넣으면 충돌이 끝없이 돈다.
                    await apply(modified: [server], deleted: [])
                case .zoneNotFound:
                    saveZone()
                    forget(id)
                    add([.saveRecord(id)])
                case .unknownItem:
                    forget(id)
                    // 서버에 없는 기록이다 — Moment 를 다시 저장하면 되살아난다(§3-4). Day 만 다시 올린다.
                    if case .moment(let uuid) = SyncRecords.ref(id) {
                        Self.dropUnknown(uuid, from: store)
                        refreshSurfaces()
                    } else {
                        add([.saveRecord(id)])
                    }
                case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                     .notAuthenticated, .operationCancelled, .requestRateLimited:
                    break  // 엔진이 알아서 다시 시도한다
                default:
                    log.error("save failed \(id.recordName, privacy: .public): \(failure.error.localizedDescription, privacy: .public)")
                }
            }
            for (id, error) in e.failedRecordDeletes {
                log.error("delete failed \(id.recordName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            persistSystemFields()

        default:
            break
        }
    }

    nonisolated func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                               syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        guard !pending.isEmpty else { return nil }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { id in
            await self.record(for: id)
        }
    }
}

private extension CKSyncEngine.PendingRecordZoneChange {
    var zoneID: CKRecordZone.ID? {
        switch self {
        case .saveRecord(let id), .deleteRecord(let id): id.zoneID
        @unknown default: nil
        }
    }
}
