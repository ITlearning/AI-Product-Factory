import Photos

/// 사진 로컬 ID ↔ iCloud ID 매핑. 앱 타깃 전용(Photos import) — Shared 는 이 타입을 모른다.
enum CloudIDMapper {

    /// assetID 는 있는데 cloudID 가 없는 기록에 사진 앱의 cloudID 를 붙인다(담기·입양 뒤, 옛 기록).
    @MainActor
    static func assignMissing(store: DayStore) async {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite).allowsRead else { return }
        let pending = store.moments.filter { $0.assetID != nil && $0.cloudID == nil }
        guard !pending.isEmpty else { return }
        let locals = pending.compactMap(\.assetID)
        let found: [String: String] = await Task.detached(priority: .utility) {
            let map = PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers: locals)
            return map.compactMapValues { try? $0.get().stringValue }
        }.value
        for m in pending {
            if let local = m.assetID, let cloud = found[local] { store.setCloudID(m.id, cloud) }
        }
    }

    /// 다른 기기에서 받은 기록의 cloudID 를 이 기기 에셋으로 찾는다. 못 찾으면 그대로 둔다(다음 기회).
    @MainActor
    static func resolve(store: DayStore) async {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite).allowsRead else { return }
        let pending = store.unresolved
        guard !pending.isEmpty else { return }
        let clouds = pending.compactMap(\.cloudID)
        let found: [String: String] = await Task.detached(priority: .utility) {
            let ids = clouds.map { PHCloudIdentifier(stringValue: $0) }
            let map = PHPhotoLibrary.shared().localIdentifierMappings(for: ids)
            var out: [String: String] = [:]
            for (cloud, result) in map { if let local = try? result.get() { out[cloud.stringValue] = local } }
            return out
        }.value
        for m in pending {
            if let cloud = m.cloudID, let local = found[cloud] { store.resolveAsset(m.id, assetID: local) }
        }
    }

    @MainActor
    static func refresh(store: DayStore) async {
        await assignMissing(store: store)
        await resolve(store: store)
    }
}

private extension PHAuthorizationStatus {
    var allowsRead: Bool { self == .authorized || self == .limited }
}
