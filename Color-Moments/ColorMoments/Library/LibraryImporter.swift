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

    func importAssets(_ assets: [PHAsset], into store: DayStore) async -> Int {
        let batch = UUID()
        var count = 0
        for asset in assets {
            let id = asset.localIdentifier
            guard !store.containsAsset(id) else { continue }
            guard let data = await Self.imageData(for: asset) else { continue }
            // 색 추출은 CPU 무거운 일이라 메인 액터 밖(백그라운드 스레드)에서 돌린다. 원본은 파일로 쓰지 않는다 — assetID 로 바로 Moment.
            guard let hex = await Task.detached(priority: .userInitiated, operation: {
                Self.process(data: data)
            }).value else { continue }
            guard !store.containsAsset(id) else { continue } // 위 await 들 사이 상태가 바뀌었을 수 있어 넣기 직전 다시 확인
            let place = asset.location.map {
                Place(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude, accuracy: $0.horizontalAccuracy)
            }
            let before = store.moments.count
            store.add(Moment(capturedAt: asset.creationDate ?? Date(), colorHex: hex, fileName: Moment.assetFileName(for: id),
                              source: .library, assetID: id, place: place, addedAt: Date(), batchID: batch))
            if store.moments.count > before { count += 1 } // add 가 파일 이름 중복으로 조용히 무시했을 수 있다
        }
        await CloudIDMapper.assignMissing(store: store)
        return count
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
