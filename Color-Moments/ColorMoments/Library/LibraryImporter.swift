import CoreImage
import CoreLocation
import Foundation
import Photos

@MainActor
final class LibraryImporter {

    /// range — 그 사이에 찍힌 것만(하루 경계 04시 기준으로 넘긴다).
    nonisolated static func fetchOptions(range: Range<Date>? = nil, favoritesOnly: Bool = false) -> PHFetchOptions {
        let o = PHFetchOptions()
        var parts = [NSPredicate(
            format: "mediaType == %d AND !((mediaSubtypes & %d) == %d)",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaSubtype.photoScreenshot.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue)]
        if let range {
            parts.append(NSPredicate(format: "creationDate >= %@ AND creationDate < %@",
                                     range.lowerBound as NSDate, range.upperBound as NSDate))
        }
        if favoritesOnly { parts.append(NSPredicate(format: "favorite == YES")) }
        o.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: parts)
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        o.includeAssetSourceTypes = [.typeUserLibrary]
        return o
    }

    /// 앱 안의 사진 권한 요청은 모두 여기로 — 받은 뒤 사진 변경 감시를 켜야 한다(`.photoAccessRequested`).
    static func requestAccess() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        NotificationCenter.default.post(name: .photoAccessRequested, object: nil)
        return status
    }

    /// 이만큼 모이면 한 번에 넣는다 — 한 장씩 넣으면 장마다 홈·사진첩 격자가 다시 그려진다.
    static let addChunk = 12

    /// 가져오는 중 — 몇 장 중 몇 장.
    struct Progress: Equatable, Sendable {
        var done: Int
        var total: Int
    }

    /// 이번에 실제로 넣은 기록의 하루(dayKey)들 — iCloud 로 그 사이 들어온 원격 기록은 섞이지 않는다.
    func importAssets(_ assets: [PHAsset], into store: DayStore,
                      onProgress: ((Progress) -> Void)? = nil) async -> Set<String> {
        let batch = UUID()
        var progress = Progress(done: 0, total: assets.count)
        onProgress?(progress)
        var dayKeys: Set<String> = []
        var buffer: [Moment] = []
        func flush() async {
            // 위 await 들 사이 상태가 바뀌었을 수 있어 넣기 직전 다시 확인한다. add 는 파일 이름 중복도 조용히 거른다.
            let fresh = buffer.filter { !store.containsAsset($0.assetID ?? "") }
            buffer = []
            for m in store.add(contentsOf: fresh) { dayKeys.insert(m.dayKey) }
            await FramePause.next()
        }
        for asset in assets {
            defer {
                progress.done += 1
                onProgress?(progress)
            }
            let id = asset.localIdentifier
            guard !store.containsAsset(id), !buffer.contains(where: { $0.assetID == id }) else { continue }
            guard let data = await Self.imageData(for: asset) else { continue }
            // 색 추출은 CPU 무거운 일이라 메인 액터 밖(백그라운드 스레드)에서 돌린다. 원본은 파일로 쓰지 않는다 — assetID 로 바로 Moment.
            guard let hex = await Task.detached(priority: .userInitiated, operation: {
                Self.process(data: data)
            }).value else { continue }
            let place = asset.location.map {
                Place(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude, accuracy: $0.horizontalAccuracy)
            }
            buffer.append(Moment(capturedAt: asset.creationDate ?? Date(), colorHex: hex,
                                 fileName: Moment.assetFileName(for: id),
                                 source: .library, assetID: id, place: place, addedAt: Date(), batchID: batch))
            if buffer.count >= Self.addChunk { await flush() }
        }
        if !buffer.isEmpty { await flush() }
        await CloudIDMapper.assignMissing(store: store)
        return dayKeys
    }

    nonisolated private static func process(data: Data) -> String? {
        autoreleasepool {
            guard let ci = CIImage(data: data) else { return nil }
            return ColorExtractor.symbolicColor(for: ci).hex
        }
    }

    private static func imageData(for asset: PHAsset) async -> Data? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current

        return await withCheckedContinuation { continuation in
            var resumed = false
            let lock = NSLock()
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                // highQualityFormat 은 콜백 1회가 계약이지만, 재호출돼도 두 번째 resume 은 크래시라 방어한다.
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: data)
            }
        }
    }
}

extension Notification.Name {
    static let photoAccessRequested = Notification.Name("photoAccessRequested")
}

/// 오늘(04시 경계) 찍은 사진 중 아직 몽돌에 없는 것 — 기본 카메라로 찍어도 고르거나 ♥로 담을 수 있게.
enum TodayPhotos {
    static func range(dayKey: String) -> Range<Date>? {
        guard let end = Moment.sealDate(for: dayKey),
              let start = Moment.calendar.date(byAdding: .day, value: -1, to: end) else { return nil }
        return start..<end
    }

    /// ids — 이미 몽돌에 있는 사진. capturedAt — 몽돌로 찍어 사진 앱에 저장 중인 것(assetID 가 붙기 전)은
    /// 찍은 시각이 같다(AssetSaver 가 creationDate 를 그대로 적는다) — 그 사이에 「기본 카메라 사진」으로 세지 않게.
    static func pending(dayKey: String, excluding ids: Set<String>, capturedAt: [Date] = [],
                        favoritesOnly: Bool = false) async -> [PHAsset] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited, let range = range(dayKey: dayKey) else { return [] }
        let times = capturedAt.map(\.timeIntervalSinceReferenceDate).sorted()
        return await Task.detached(priority: .utility) {
            var out: [PHAsset] = []
            PHAsset.fetchAssets(with: LibraryImporter.fetchOptions(range: range, favoritesOnly: favoritesOnly))
                .enumerateObjects { a, _, _ in
                    guard !ids.contains(a.localIdentifier) else { return }
                    if let t = a.creationDate?.timeIntervalSinceReferenceDate,
                       times.contains(where: { abs($0 - t) < 1.5 }) { return }
                    out.append(a)
                }
            return out
        }.value
    }
}

/// 사진 앱에서 ♥를 누른 오늘 사진을 알아서 담는다(설정에서 끌 수 있다, 기본 켬).
/// 한 번 담은 사진은 기억한다 — 몽돌에서 지웠는데 앱을 열 때마다 되살아나면 안 된다.
@MainActor
enum FavoriteAdopter {
    static let enabledKey = "adoptsFavorites"
    private static let adoptedKey = "favoriteAdoptedIDs"
    private static let keep = 400

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    static func run(store: DayStore, defaults: UserDefaults = .standard) async {
        guard isEnabled(defaults) else { return }
        let adopted = defaults.stringArray(forKey: adoptedKey) ?? []
        let known = Set(store.moments.compactMap(\.assetID)).union(adopted)
        let today = Moment.dayKey(for: Date())
        let fresh = await TodayPhotos.pending(dayKey: today, excluding: known,
                                              capturedAt: store.moments(on: today).map(\.capturedAt), favoritesOnly: true)
        guard !fresh.isEmpty, isEnabled(defaults) else { return }
        _ = await LibraryImporter().importAssets(fresh, into: store)
        defaults.set(Array((adopted + fresh.map(\.localIdentifier)).suffix(keep)), forKey: adoptedKey)
    }
}
