import Photos

/// 사진 앱에서 지운 사진을 몽돌에서도 정리한다. 전체 접근(`.authorized`)일 때만 —
/// 「선택한 사진만」 접근에서 안 보이는 사진은 지운 게 아니라 그냥 못 고른 것뿐이라 지우지 않는다.
enum AssetReconciler {

    /// 순수 함수 — `ids` 중 `found`에 없는 것들. `fullAccess`가 아니면 늘 빈 집합.
    /// 안전장치: `found`가 통째로 비어 있으면(조회 실패 등) 아무것도 안 지운다.
    /// 지울 개수가 `max(3, ids.count / 5)`(최소 3개 또는 20%)를 넘으면 그 회차는 건너뛴다 —
    /// 한 번의 잘못된 조회로 기록 전체가 지워지는 걸 막는 덫.
    static func missing(ids: Set<String>, found: Set<String>, fullAccess: Bool) -> Set<String> {
        guard fullAccess else { return [] }
        guard !(found.isEmpty && !ids.isEmpty) else { return [] }
        let candidates = ids.subtracting(found)
        let cap = max(3, ids.count / 5)
        guard candidates.count <= cap else { return [] }
        return candidates
    }

    /// 지금 저장소에 있는 모든 assetID 를 사진 앱과 대조해 사라진 것들을 지운다.
    @MainActor
    static func reconcile(store: DayStore) {
        let fullAccess = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
        let ids = Set(store.moments.compactMap(\.assetID))
        guard fullAccess, !ids.isEmpty else { return }

        var found = Set<String>()
        PHAsset.fetchAssets(withLocalIdentifiers: Array(ids), options: nil)
            .enumerateObjects { asset, _, _ in found.insert(asset.localIdentifier) }

        let toRemove = missing(ids: ids, found: found, fullAccess: fullAccess)
        guard !toRemove.isEmpty else { return }
        store.remove(assetIDs: toRemove)
    }
}

/// 사진 앱이 바뀔 때(다른 사진에서 지워도) 알려주는 옵저버. 앱 시작 때 한 번만 등록한다.
/// `missing()` 의 상한(20%)과 달리, 여기는 시스템이 "명시적으로 지워졌다"고 확인해준 것만 다루므로
/// 상한 없이 그대로 지운다 — `changeDetails.removedObjects` 는 조회 실패로 전부 빠지는 경우가 없다.
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
                let removedIDs = Set(details.removedObjects.map(\.localIdentifier))
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
