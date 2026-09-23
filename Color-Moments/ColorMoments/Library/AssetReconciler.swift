import Photos

/// 사진 앱에서 지운 사진을 몽돌에서도 정리한다. 전체 접근(`.authorized`)일 때만 —
/// 「선택한 사진만」 접근에서 안 보이는 사진은 지운 게 아니라 그냥 못 고른 것뿐이라 지우지 않는다.
enum AssetReconciler {

    /// 순수 함수 — `ids` 중 `found`에 없는 것들. `fullAccess`가 아니면 늘 빈 집합.
    static func missing(ids: Set<String>, found: Set<String>, fullAccess: Bool) -> Set<String> {
        guard fullAccess else { return [] }
        return ids.subtracting(found)
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
final class AssetReconcilerObserver: NSObject, PHPhotoLibraryChangeObserver {

    private let store: DayStore

    init(store: DayStore) {
        self.store = store
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        let store = store
        Task { @MainActor in
            AssetReconciler.reconcile(store: store)
        }
    }
}
