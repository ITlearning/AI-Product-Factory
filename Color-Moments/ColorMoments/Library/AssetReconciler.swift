import Photos

/// 사진 앱에서 지운 사진을 몽돌에서도 정리한다. 전체 접근(`.authorized`)일 때만 —
/// 「선택한 사진만」 접근에서 안 보이는 사진은 지운 게 아니라 그냥 못 고른 것뿐이라 지우지 않는다.
enum AssetReconciler {

    /// 순수 함수 — `ids` 중 `found`에 없는 것들. `fullAccess`가 아니면 늘 빈 집합.
    /// 안전장치: `found`가 통째로 비어 있으면(조회 실패 등) 아무것도 안 지운다.
    /// 지울 개수가 상한(`cap`)을 넘으면 그 회차는 건너뛴다 — 한 번의 잘못된 조회로 기록 전체가 지워지는 걸 막는 덫.
    static func missing(ids: Set<String>, found: Set<String>, fullAccess: Bool) -> Set<String> {
        guard fullAccess else { return [] }
        guard !(found.isEmpty && !ids.isEmpty) else { return [] }
        return cappedRemoval(ids.subtracting(found), tracked: ids.count)
    }

    /// 최소 3개 또는 추적 중인 에셋의 20%.
    static func cap(tracked: Int) -> Int { max(3, tracked / 5) }

    /// 한 번에 지울 게 상한을 넘으면 통째로 건너뛴다. 지운 기록은 모든 기기로 번지므로 옵저버 경로도 같은 상한을 쓴다.
    static func cappedRemoval(_ removed: Set<String>, tracked: Int) -> Set<String> {
        removed.count <= cap(tracked: tracked) ? removed : []
    }

    struct Plan: Equatable {
        /// 옛 assetID → cloudID 로 다시 찾은 새 assetID
        var reassign: [String: String] = [:]
        var remove: Set<String> = []
    }

    /// 순수 함수 — `relocated` 는 못 찾은 assetID 중 cloudID 로 다시 찾은 것(옛 → 새).
    /// 다시 찾은 것은 지우지 않고 바꿔 끼우고, 남은 것만 `missing()` 규칙(빈 조회·상한)으로 판정한다.
    /// `otherAssetIDs`: 이 판정 밖에 있는 다른 기록들이 이미 쓰고 있는 assetID — 충돌 판정에 쓴다.
    /// 이 기기에 사본 파일이 남았어도 사진 앱에서 지운 것으로 본다 — 지운 뒤 사본도 지운다(`leftoverFiles`).
    static func plan(ids: Set<String>, found: Set<String>, relocated: [String: String],
                      otherAssetIDs: Set<String> = [], fullAccess: Bool) -> Plan {
        guard fullAccess else { return Plan() }
        let candidates = ids.subtracting(found)

        // 매핑 결과가 옛 ID 와 같다 — 조회가 놓쳤을 뿐 사진은 실제로 있다는 뜻. 지우지 않는다.
        let confirmedLocated = candidates.filter { relocated[$0] == $0 }

        let changed = relocated.filter { candidates.contains($0.key) && $0.key != $0.value }

        // 여러 기록이 같은 새 ID 로 겹치면 어느 쪽이 맞는지 모른다 — 둘 다 판정 보류.
        var valueCounts: [String: Int] = [:]
        for value in changed.values { valueCounts[value, default: 0] += 1 }
        let collidingValues = Set(valueCounts.filter { $0.value > 1 }.keys)

        // 새 ID 가 추적 중인 어떤 assetID 와도 겹치면 충돌 — 판정 보류. ids 를 빼면 a→b 로 살린 기록이
        // 같은 회차의 remove(b) 에 함께 지워진다.
        let occupied = found.union(otherAssetIDs).union(ids)

        let reassign = changed.filter { !occupied.contains($0.value) && !collidingValues.contains($0.value) }
        // 충돌로 제외된 것들은 reassign 에도 remove 에도 넣지 않는다(판정 보류).
        let deferred = Set(changed.keys).subtracting(reassign.keys)

        let located = found.union(reassign.keys).union(confirmedLocated)
        // 상한은 보류 전 후보 수로 잰다 — 보류분을 먼저 빼면 같은 회차에서 더 많이 지워진다.
        let remove = missing(ids: ids, found: located, fullAccess: fullAccess).subtracting(deferred)
        return Plan(reassign: reassign, remove: remove)
    }

    /// 이 기기에 실제 파일이 있는 이름인지 — 자리 이름(asset-·remote-)은 파일이 없다.
    static func holdsLocalFile(fileName: String, exists: (String) -> Bool) -> Bool {
        !fileName.hasPrefix("asset-") && !fileName.hasPrefix("remote-") && exists(fileName)
    }

    /// 순수 함수 — 지운 기록의 사본 파일 이름 중 남은 기록이 아무도 안 쓰는 것. 자리 이름은 파일이 없어 뺀다.
    static func leftoverFiles(removed: [Moment], remaining: [Moment]) -> Set<String> {
        let inUse = Set(remaining.map(\.fileName))
        return Set(removed.map(\.fileName).filter {
            holdsLocalFile(fileName: $0, exists: { _ in true }) && !inUse.contains($0)
        })
    }

    /// 실제 디스크 확인 — 메인 밖에서.
    static func localFileNames(_ fileNames: [String]) async -> Set<String> {
        guard !fileNames.isEmpty else { return [] }
        return await Task.detached(priority: .utility) {
            let fm = FileManager.default
            return Set(fileNames.filter {
                holdsLocalFile(fileName: $0, exists: { fm.fileExists(atPath: ShotImage.url($0).path) })
            })
        }.value
    }

    /// 24시간 창 안의 누적 삭제 상태. 나눠서 조금씩 지우는 걸 막는다 — 지운 기록은 iCloud 로 모든 기기에 번진다.
    struct Budget: Codable, Equatable {
        var windowStart: Date
        var trackedAtStart: Int
        var removedSoFar: Int
    }

    private static let budgetWindow: TimeInterval = 24 * 3600
    static let budgetDefaultsKey = "reconcileBudget"

    /// 순수 함수 — 이번에 지울 `removing` 개를 지금 창의 누적치에 더해도 상한(그 창 시작 때 추적 수 기준)을
    /// 넘지 않는지 본다. 창이 없거나 24시간이 지났으면 새 창을 연다. 넘으면 그 회차는 통째로 거부하고
    /// (부분 삭제 금지) 누적치는 그대로 둔다.
    static func budgetAllows(removing: Int, now: Date, state: Budget?, tracked: Int) -> (Bool, Budget) {
        let active: Budget
        // 시계를 되돌려 음수가 되면 새 창 — 창이 끝없이 이어져 정상 삭제가 막히지 않게.
        if let state, case let dt = now.timeIntervalSince(state.windowStart), dt >= 0, dt < budgetWindow {
            active = state
        } else {
            active = Budget(windowStart: now, trackedAtStart: tracked, removedSoFar: 0)
        }
        let projected = active.removedSoFar + removing
        guard projected <= cap(tracked: active.trackedAtStart) else { return (false, active) }
        return (true, Budget(windowStart: active.windowStart, trackedAtStart: active.trackedAtStart,
                             removedSoFar: projected))
    }

    // 동시에 두 개가 돌면 서로의 조회 결과를 밟고 지나갈 수 있다 — 한 번에 하나만, 돌던 중 들어온 요청은
    // 끝난 뒤 한 번 더(dirty 플래그로 합쳐서).
    @MainActor private static var reconciling = false
    @MainActor private static var dirty = false

    /// 지금 저장소에 있는 모든 assetID 를 사진 앱과 대조해 사라진 것들을 지운다.
    /// 복원 등으로 로컬 ID 만 바뀐 사진은 cloudID 로 다시 찾아 붙인다.
    @MainActor
    static func reconcile(store: DayStore, defaults: UserDefaults = .standard) async {
        guard !reconciling else { dirty = true; return }
        reconciling = true
        defer { reconciling = false }
        repeat {
            dirty = false
            await run(store: store, defaults: defaults)
        } while dirty
    }

    @MainActor
    private static func run(store: DayStore, defaults: UserDefaults) async {
        let fullAccess = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
        // 조회를 기다리는 사이 새로 담긴 기록은 found 에 없다 — 판정은 조회 전 스냅샷으로만 한다.
        let snapshot = store.moments
        let ids = Set(snapshot.compactMap(\.assetID))
        guard fullAccess, !ids.isEmpty else { return }

        let found = await existing(Array(ids))

        let lost = snapshot.filter { m in m.assetID.map { !found.contains($0) } ?? false }
        var relocated: [String: String] = [:]
        let clouds = lost.compactMap(\.cloudID)
        if !clouds.isEmpty {
            let locals = await CloudIDMapper.localIDs(forCloudIDs: clouds)
            for m in lost {
                guard let old = m.assetID, let new = m.cloudID.flatMap({ locals[$0] }) else { continue }
                relocated[old] = new
            }
        }

        let plan = plan(ids: ids, found: found, relocated: relocated, fullAccess: fullAccess)
        if !plan.reassign.isEmpty {
            store.reassignAssets(store.moments.compactMap { m in
                m.assetID.flatMap { plan.reassign[$0] }.map { (m.id, $0) }
            })
        }
        guard !plan.remove.isEmpty else { return }

        let state = loadBudget(defaults: defaults)
        let (allowed, budget) = budgetAllows(removing: plan.remove.count, now: Date(), state: state, tracked: ids.count)
        saveBudget(budget, defaults: defaults)
        guard allowed else { return }
        let doomed = removalIDs(snapshot: snapshot, remove: plan.remove, current: store.moments)
        let removed = snapshot.filter { doomed.contains($0.id) }
        store.remove(ids: doomed)
        let remainingBeforeFlush = store.moments
        // 삭제가 디스크에 닿기 전에 사본을 지우면 kill 뒤 되살아난 기록이 빈 파일을 가리킨다.
        guard await store.flushAfterLoad() else { return }
        // 기다리는 사이 메모리에서만 빠진 기록(원격 삭제 등)은 아직 디스크에 있다 — 그 파일도 쓰는 중으로 본다.
        let files = leftoverFiles(removed: removed, remaining: remainingBeforeFlush + store.moments)
        guard !files.isEmpty else { return }
        await Task.detached(priority: .utility) {
            for name in files { try? FileManager.default.removeItem(at: ShotImage.url(name)) }
        }.value
    }

    /// 판정한 스냅샷 안의 기록만 — assetID 로 지우면 조회 대기 중 같은 사진으로 새로 담긴 기록까지 지워진다.
    static func removalIDs(snapshot: [Moment], remove: Set<String>) -> Set<Moment.ID> {
        Set(snapshot.filter { $0.assetID.map(remove.contains) ?? false }.map(\.id))
    }

    /// 조회를 기다리는 사이 수동 복구로 assetID 가 바뀐 기록은 뺀다 — 이제 새 사진을 가리킨다.
    static func removalIDs(snapshot: [Moment], remove: Set<String>, current: [Moment]) -> Set<Moment.ID> {
        let now = Dictionary(current.map { ($0.id, $0.assetID) }, uniquingKeysWith: { a, _ in a })
        return removalIDs(snapshot: snapshot, remove: remove).filter { id in
            now[id].flatMap { $0 }.map(remove.contains) ?? false
        }
    }

    /// 사진 앱에 아직 있는 로컬 ID — 수천 개 조회는 메인 밖에서.
    static func existing(_ ids: [String]) async -> Set<String> {
        guard !ids.isEmpty else { return [] }
        return await Task.detached(priority: .utility) {
            var found = Set<String>()
            PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
                .enumerateObjects { asset, _, _ in found.insert(asset.localIdentifier) }
            return found
        }.value
    }

    private static func loadBudget(defaults: UserDefaults) -> Budget? {
        guard let data = defaults.data(forKey: budgetDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(Budget.self, from: data)
    }

    private static func saveBudget(_ budget: Budget, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(budget) else { return }
        defaults.set(data, forKey: budgetDefaultsKey)
    }
}

/// 사진 앱이 바뀔 때(다른 사진에서 지워도) 알려주는 옵저버. 사진 권한이 생긴 뒤에만 켠다.
final class AssetReconcilerObserver: NSObject, PHPhotoLibraryChangeObserver {

    /// 사진 앱에 닿는 부분 — 테스트는 가짜로 바꾼다.
    struct Env {
        var access: () -> PHAuthorizationStatus
        var register: (PHPhotoLibraryChangeObserver) -> Void
        var unregister: (PHPhotoLibraryChangeObserver) -> Void

        static let live = Env(
            access: { PHPhotoLibrary.authorizationStatus(for: .readWrite) },
            register: { PHPhotoLibrary.shared().register($0) },
            unregister: { PHPhotoLibrary.shared().unregisterChangeObserver($0) }
        )
    }

    static let settleDelay: Duration = .milliseconds(400)

    private let store: DayStore
    private let env: Env
    private(set) var isActive = false
    private var fetchResult: PHFetchResult<PHAsset>?
    private var trackedIDs: Set<String> = []
    private var fetchGeneration = 0
    private var settling: Task<Void, Never>?
    private var settleAgain = false
    private var appliedChanges = 0
    private var refetchNeeded = false
    private var bumpAllWhenQuiet = false

    init(store: DayStore, env: Env = .live) {
        self.store = store
        self.env = env
        super.init()
    }

    deinit {
        if isActive { env.unregister(self) }
    }

    static func observes(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }

    /// 여러 번 불러도 한 번만 켠다. 권한 미결정에서 등록하면 그 자리에서 사진 권한 창이 뜬다.
    @MainActor
    func activateIfAllowed() {
        guard !isActive, Self.observes(env.access()) else { return }
        isActive = true
        env.register(self)
        Task { @MainActor [weak self] in await self?.refreshFetchResult() }
    }

    @MainActor
    private func refreshFetchResult() async {
        fetchGeneration += 1
        let generation = fetchGeneration
        let appliedBefore = appliedChanges
        refetchNeeded = false
        let ids = Set(store.moments.compactMap(\.assetID))
        guard !ids.isEmpty else { fetchResult = nil; trackedIDs = []; return }
        let result = await Task.detached(priority: .utility) {
            PHAsset.fetchAssets(withLocalIdentifiers: Array(ids), options: nil)
        }.value
        // 조회가 겹치면 늦게 끝난 옛 조회가 새 추적 목록을 덮는다 — 마지막으로 시작한 것만 남긴다.
        guard generation == fetchGeneration else { return }
        fetchResult = result
        trackedIDs = ids
        // 기다리는 사이 옛 결과에 적용한 변경이 새 결과보다 늦었을 수 있다 — 다음 묶음에서 다시 조회한다.
        if appliedChanges != appliedBefore {
            refetchNeeded = true
            scheduleSettle()
        }
    }

    /// 추적 결과에 대한 변경 — `PHFetchResultChangeDetails` 에서 판정에 쓰는 것만.
    struct TrackedChange: Equatable {
        var changed: [String] = []
        var inserted: [String] = []
        var removedCount = 0
        var incremental = true
    }

    struct ChangeEffect: Equatable {
        var bumpIDs: Set<String> = []
        /// 어떤 사진이 바뀐 건지 모른다 — 알림이 잦아든 뒤 뜬 칸에 한 번 다시 물어본다(원본이 늦게 내려온 칸).
        var bumpsAllWhenQuiet = false
        var reconciles = false
    }

    /// 순수 함수 — 변경 한 번에 할 일. 제한 접근에서는 선택 해제도 삭제로 오므로 정리는 전체 접근일 때만.
    static func effect(tracking: Bool, details: TrackedChange?, fullAccess: Bool) -> ChangeEffect {
        guard tracking, let details else { return ChangeEffect(bumpsAllWhenQuiet: true) }
        guard details.incremental else { return ChangeEffect(bumpsAllWhenQuiet: true, reconciles: fullAccess) }
        return ChangeEffect(bumpIDs: Set(details.changed + details.inserted),
                            reconciles: fullAccess && details.removedCount > 0)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // 받은 순서대로 적용해야 fetchResultAfterChanges 가 이어진다 — Task 는 순서를 보장하지 않는다.
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.apply(changeInstance) }
        }
    }

    @MainActor
    private func apply(_ change: PHChange) {
        let tracking = fetchResult != nil
        var tracked: TrackedChange?
        if let current = fetchResult, let details = change.changeDetails(for: current) {
            fetchResult = details.fetchResultAfterChanges
            appliedChanges += 1
            tracked = TrackedChange(changed: details.changedObjects.map(\.localIdentifier),
                                    inserted: details.insertedObjects.map(\.localIdentifier),
                                    removedCount: details.removedObjects.count,
                                    incremental: details.hasIncrementalChanges)
        }
        let effect = Self.effect(tracking: tracking, details: tracked, fullAccess: env.access() == .authorized)
        for id in effect.bumpIDs { ShotImage.generation.bump(assetID: id) }
        if effect.bumpsAllWhenQuiet { bumpAllWhenQuiet = true }
        // 직접 지우지 않고 reconcile() 을 부른다 — cloudID 재조회·상한 판정을 한 곳에서만 한다.
        if effect.reconciles {
            Task { @MainActor [weak self] in
                guard let self else { return }
                await AssetReconciler.reconcile(store: self.store)
                self.scheduleSettle()
            }
        }
        scheduleSettle()
    }

    /// iCloud 사진이 내려오는 동안 알림이 잇달아 온다 — cloudID 찾기와 추적 목록 재조회는 모아서 한 번씩.
    @MainActor
    private func scheduleSettle() {
        guard settling == nil else { settleAgain = true; return }
        settling = Task { @MainActor [weak self] in await self?.settle() }
    }

    @MainActor
    private func settle() async {
        repeat {
            try? await Task.sleep(for: Self.settleDelay)
            settleAgain = false
            // 먼저 찾아야 방금 이어 붙인 assetID 가 이번 재조회에 들어간다.
            await CloudIDMapper.refresh(store: store)
            if refetchNeeded || Set(store.moments.compactMap(\.assetID)) != trackedIDs { await refreshFetchResult() }
        } while settleAgain
        settling = nil
        // 잇달아 올 때 매번 올리면 불러오던 칸이 계속 끊긴다 — 잦아든 뒤 한 번만.
        if bumpAllWhenQuiet {
            bumpAllWhenQuiet = false
            ShotImage.generation.bump()
        }
    }
}
