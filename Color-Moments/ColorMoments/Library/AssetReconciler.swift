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

        // 새 ID 가 이미 찾아졌거나(found) 다른 기록의 assetID 면 충돌 — 판정 보류.
        let occupied = found.union(otherAssetIDs)

        let reassign = changed.filter { !occupied.contains($0.value) && !collidingValues.contains($0.value) }
        // 충돌로 제외된 것들은 reassign 에도 remove 에도 넣지 않는다(판정 보류).
        let deferred = Set(changed.keys).subtracting(reassign.keys)

        let located = found.union(reassign.keys).union(confirmedLocated)
        let remove = missing(ids: ids, found: located, fullAccess: fullAccess).subtracting(deferred)
        return Plan(reassign: reassign, remove: remove)
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
        if let state, now.timeIntervalSince(state.windowStart) < budgetWindow {
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
        let ids = Set(store.moments.compactMap(\.assetID))
        guard fullAccess, !ids.isEmpty else { return }

        var found = Set<String>()
        PHAsset.fetchAssets(withLocalIdentifiers: Array(ids), options: nil)
            .enumerateObjects { asset, _, _ in found.insert(asset.localIdentifier) }

        let lost = store.moments.filter { m in m.assetID.map { !found.contains($0) } ?? false }
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
        store.remove(assetIDs: plan.remove)
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

/// 사진 앱이 바뀔 때(다른 사진에서 지워도) 알려주는 옵저버. 앱 시작 때 한 번만 등록한다.
final class AssetReconcilerObserver: NSObject, PHPhotoLibraryChangeObserver {

    private let store: DayStore
    private var fetchResult: PHFetchResult<PHAsset>?

    init(store: DayStore) {
        self.store = store
        super.init()
        PHPhotoLibrary.shared().register(self)
        Task { @MainActor [weak self] in self?.refreshFetchResult() }
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    @MainActor
    private func refreshFetchResult() {
        let ids = Array(Set(store.moments.compactMap(\.assetID)))
        fetchResult = ids.isEmpty ? nil : PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // 제한 접근에서는 선택 해제도 removedObjects 로 온다 — 지운 게 아니므로 전체 접근일 때만 반영.
            // 직접 지우지 않고 reconcile() 을 부른다 — cloudID 재조회·상한 판정을 한 곳에서만 한다.
            if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized,
               let fetchResult = self.fetchResult,
               let details = changeInstance.changeDetails(for: fetchResult),
               !details.removedObjects.isEmpty {
                await AssetReconciler.reconcile(store: self.store)
            }
            // 추적 목록을 지금 저장소 기준으로 다시 세운다 — 새로 입양된 assetID 도 다음 변경부터 잡힌다.
            self.refreshFetchResult()
            // iCloud 사진이 늦게 내려와도 여기서 cloudID 를 다시 찾는다.
            Task { await CloudIDMapper.refresh(store: self.store) }
        }
    }
}
