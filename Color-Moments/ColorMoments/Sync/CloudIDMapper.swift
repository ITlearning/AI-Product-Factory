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
        store.setCloudIDs(pending.compactMap { m in m.assetID.flatMap { found[$0] }.map { (m.id, $0) } })
    }

    /// 다른 기기에서 받은 기록의 cloudID 를 이 기기 에셋으로 찾는다. 못 찾으면 그대로 둔다(다음 기회).
    @MainActor
    static func resolve(store: DayStore) async {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite).allowsRead else { return }
        let pending = store.unresolved
        guard !pending.isEmpty else { return }
        let found = await localIDs(forCloudIDs: pending.compactMap(\.cloudID))
        store.resolveAssets(pending.compactMap { m in m.cloudID.flatMap { found[$0] }.map { (m.id, $0) } })
    }

    @MainActor private static var resolving = false
    @MainActor private static var resolveAgain = false

    /// 받은 묶음마다 부른다 — 돌던 중 들어온 요청은 끝난 뒤 한 번만 더 돈다(묶음 수만큼 PhotoKit 조회가 겹치지 않게).
    @MainActor
    static func resolveCoalesced(store: DayStore) async {
        guard !resolving else { resolveAgain = true; return }
        resolving = true
        defer { resolving = false }
        repeat {
            resolveAgain = false
            await resolve(store: store)
        } while resolveAgain
    }

    @MainActor private static var settling: Task<Void, Never>?

    /// 받은 묶음이 잇달아 올 때 — 조용해진 뒤 한 번만 찾는다. 묶음마다 찾으면 못 찾은 기록 전체를 매번 PhotoKit 에 다시 묻는다.
    @MainActor
    static func resolveAfterReceiving(store: DayStore, quiet: UInt64 = 400_000_000) {
        settling?.cancel()
        settling = Task { @MainActor in
            try? await Task.sleep(nanoseconds: quiet)
            guard !Task.isCancelled else { return }
            settling = nil
            await resolveCoalesced(store: store)
        }
    }

    /// cloudID → 이 기기 로컬 ID. 못 찾은 것은 빠진다.
    static func localIDs(forCloudIDs clouds: [String]) async -> [String: String] {
        guard !clouds.isEmpty else { return [:] }
        return await Task.detached(priority: .utility) {
            let ids = clouds.map { PHCloudIdentifier(stringValue: $0) }
            let map = PHPhotoLibrary.shared().localIdentifierMappings(for: ids)
            var out: [String: String] = [:]
            for (cloud, result) in map { if let local = try? result.get() { out[cloud.stringValue] = local } }
            return out
        }.value
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
