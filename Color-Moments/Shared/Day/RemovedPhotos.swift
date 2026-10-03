import Foundation

/// 몽돌에서 뺀 사진 — 사진 앱엔 그대로 있다. 알아서 담는 길(♥ 담기·카메라 앱 사진 안내·잠금화면 재전달)이
/// 다시 들이지 않게 이 기기에 적어 둔다. 사진첩에서 직접 고르면 다시 담긴다.
/// assetID 는 이 기기 사진 ID, cloudID 는 기기마다 같은 사진 ID — 아직 이 기기 사진을 못 찾은 받은 기록은 cloudID 로만 막힌다.
public enum RemovedPhotos {
    static let assetKey = "removedAssetIDs"
    static let cloudKey = "removedCloudIDs"
    static let nameKey = "removedOriginalNames"
    static let keep = 400
    /// 알아서 담는 길은 오늘 찍은 사진만 본다 — 다른 기기에서 지운 옛 사진까지 적으면 정리 삭제 한 번에 목록이 밀린다.
    static let remoteWindow: TimeInterval = 2 * 24 * 3600

    public static func note(_ m: Moment, defaults: UserDefaults = .standard) {
        note(contentsOf: [m], defaults: defaults)
    }

    public static func note(contentsOf moments: [Moment], defaults: UserDefaults = .standard) {
        append(moments.compactMap(\.assetID), key: assetKey, defaults: defaults)
        append(moments.compactMap(\.cloudID), key: cloudKey, defaults: defaults)
        append(moments.compactMap(\.originalName), key: nameKey, defaults: defaults)
    }

    /// 다른 기기에서 지운 기록 — 이 목록은 iCloud 로 안 가서, 받은 기기가 자기가 가진 그 기록으로 다시 적는다.
    /// 중복을 합치느라 지운 기록이면 같은 사진을 가진 기록이 남아 있다 — 그건 적지 않는다.
    public static func noteGone(_ gone: [Moment], remaining: [Moment], now: Date = Date(),
                                defaults: UserDefaults = .standard) {
        let recent = gone.filter { now.timeIntervalSince($0.capturedAt) < remoteWindow }
        guard !recent.isEmpty else { return }
        let assets = Set(remaining.compactMap(\.assetID)), clouds = Set(remaining.compactMap(\.cloudID))
        note(contentsOf: recent.filter { m in
            !(m.assetID.map(assets.contains) ?? false) && !(m.cloudID.map(clouds.contains) ?? false)
        }, defaults: defaults)
    }

    public static func assetIDs(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: assetKey) ?? [])
    }

    public static func cloudIDs(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: cloudKey) ?? [])
    }

    /// 잠금화면 세션 파일 이름 — 무효화에 실패한 세션이 다시 오면 이 이름으로 온다.
    public static func originalNames(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: nameKey) ?? [])
    }

    /// 후보 사진(이 기기 ID) 중 cloudID 로 뺀 사진이 아닌 것. cloudID 를 모르는 사진은 남긴다.
    public static func keeping(_ localIDs: [String], cloudIDOf: [String: String], removed: Set<String>) -> Set<String> {
        Set(localIDs.filter { id in cloudIDOf[id].map { !removed.contains($0) } ?? true })
    }

    private static func append(_ values: [String], key: String, defaults: UserDefaults) {
        guard !values.isEmpty else { return }
        var seen = Set<String>()
        let fresh = values.filter { seen.insert($0).inserted }
        let list = (defaults.stringArray(forKey: key) ?? []).filter { !seen.contains($0) }
        defaults.set(Array((list + fresh).suffix(keep)), forKey: key)
    }
}
