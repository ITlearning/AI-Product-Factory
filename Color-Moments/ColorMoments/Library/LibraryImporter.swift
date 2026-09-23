import CoreImage
import CoreLocation
import Foundation
import Photos
import UIKit

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
            guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) else { continue }
            let fileName = "library-\(String(WordPicker.fnv1a(id), radix: 16)).jpg"
            guard let url = ShotStore.save(jpeg, name: fileName) else { continue }
            guard let ci = CIImage(contentsOf: url) else { continue }
            let hex = ColorExtractor.symbolicColor(for: ci).hex
            let place = asset.location.map {
                Place(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude, accuracy: $0.horizontalAccuracy)
            }
            store.add(Moment(capturedAt: asset.creationDate ?? Date(), colorHex: hex, fileName: fileName,
                              source: .library, assetID: id, place: place, addedAt: Date(), batchID: batch))
            count += 1
        }
        return count
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
