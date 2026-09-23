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
    static func plan(ids: Set<String>, found: Set<String>, relocated: [String: String], fullAccess: Bool) -> Plan {
        guard fullAccess else { return Plan() }
        let candidates = ids.subtracting(found)
        let reassign = relocated.filter { candidates.contains($0.key) && $0.key != $0.value }
        let located = found.union(reassign.keys)
        return Plan(reassign: reassign, remove: missing(ids: ids, found: located, fullAccess: fullAccess))
    }

    /// 지금 저장소에 있는 모든 assetID 를 사진 앱과 대조해 사라진 것들을 지운다.
    /// 복원 등으로 로컬 ID 만 바뀐 사진은 cloudID 로 다시 찾아 붙인다.
    @MainActor
    static func reconcile(store: DayStore) async {
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
        store.remove(assetIDs: plan.remove)
    }
}

/// 사진 앱이 바뀔 때(다른 사진에서 지워도) 알려주는 옵저버. 앱 시작 때 한 번만 등록한다.
/// `removedObjects` 는 조회 실패로 빠지진 않지만 「iCloud 사진 끄기 → iPhone 에서 제거」 한 번에 전부 올 수 있어
/// 폴링과 같은 상한을 둔다.
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
            if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized,
               let fetchResult = self.fetchResult,
               let details = changeInstance.changeDetails(for: fetchResult) {
                let tracked = Set(self.store.moments.compactMap(\.assetID)).count
                let removedIDs = AssetReconciler.cappedRemoval(Set(details.removedObjects.map(\.localIdentifier)),
                                                               tracked: tracked)
                if !removedIDs.isEmpty {
                    self.store.remove(assetIDs: removedIDs)
                }
            }
            // 추적 목록을 지금 저장소 기준으로 다시 세운다 — 새로 입양된 assetID 도 다음 변경부터 잡힌다.
            self.refreshFetchResult()
            // iCloud 사진이 늦게 내려와도 여기서 cloudID 를 다시 찾는다.
            Task { await CloudIDMapper.refresh(store: self.store) }
        }
    }
}
