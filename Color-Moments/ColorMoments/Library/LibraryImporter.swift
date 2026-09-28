import CoreImage
import CoreLocation
import Foundation
import Photos

@MainActor
final class LibraryImporter {

    static func fetchOptions() -> PHFetchOptions {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(
            format: "mediaType == %d AND !((mediaSubtypes & %d) == %d)",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaSubtype.photoScreenshot.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue)
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        o.includeAssetSourceTypes = [.typeUserLibrary]
        return o
    }

    static func requestAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// 이만큼 모이면 한 번에 넣는다 — 한 장씩 넣으면 장마다 홈·사진첩 격자가 다시 그려진다.
    static let addChunk = 12

    /// 이번에 실제로 넣은 기록의 하루(dayKey)들 — iCloud 로 그 사이 들어온 원격 기록은 섞이지 않는다.
    func importAssets(_ assets: [PHAsset], into store: DayStore) async -> Set<String> {
        let batch = UUID()
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
