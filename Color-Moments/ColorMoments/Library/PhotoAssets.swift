import CoreLocation
import Photos
import UIKit

/// Shared 의 `AssetImageSource` 를 사진 앱으로 채우는 실제 구현. 앱 타깃에서만 Photos 를 안다.
final class PhotoAssetSource: AssetImageSource, @unchecked Sendable {

    func image(assetID: String, maxPixel: CGFloat) -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else {
            return nil
        }

        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        let targetSize: CGSize
        let contentMode: PHImageContentMode
        if maxPixel == .greatestFiniteMagnitude {
            targetSize = PHImageManagerMaximumSize
            contentMode = .aspectFit
        } else {
            targetSize = CGSize(width: maxPixel, height: maxPixel)
            contentMode = .aspectFill
        }

        var image: UIImage?
        PHImageManager.default().requestImage(
            for: asset, targetSize: targetSize, contentMode: contentMode, options: options
        ) { result, _ in
            image = result
        }
        return image
    }
}

/// 파일 → 사진 앱 저장. placeholder 의 localIdentifier 는 performChanges 블록 밖에서는 못 읽으므로 안에서 꺼내둔다.
enum AssetSaver {

    static func save(fileURL: URL, creationDate: Date, location: CLLocation?) async -> String? {
        var placeholderID: String?
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: fileURL, options: nil)
                request.creationDate = creationDate
                request.location = location
                placeholderID = request.placeholderForCreatedAsset?.localIdentifier
            }
            return placeholderID
        } catch {
            return nil
        }
    }
}

/// 파일로 남은 Moment 를 사진 앱으로 옮기는 흐름 — 찍은 직후·잠금화면 가져온 직후·앱 시작(옛 사진)에서 같은 함수를 쓴다.
enum AssetAdopter {

    @MainActor
    static func adopt(_ m: Moment, store: DayStore) async {
        guard m.assetID == nil else { return }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        let fileURL = ShotImage.url(m.fileName)
        let location = m.place.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        guard let assetID = await AssetSaver.save(fileURL: fileURL, creationDate: m.capturedAt, location: location) else {
            return
        }

        // 저장이 실제로 성공했을 때만 입양하고 파일을 지운다 — 실패하면 다음에 다시 시도된다.
        store.adopt(m.id, assetID: assetID)
        try? FileManager.default.removeItem(at: fileURL)
    }

    @MainActor
    static func adoptAll(store: DayStore) async {
        // 사진첩에서 담은 옛 사본은 이미 assetID 가 있어 에셋으로 그려진다 — 남은 파일만 고아라 지운다.
        for m in store.moments where m.assetID != nil && m.fileName.hasPrefix("library-") {
            try? FileManager.default.removeItem(at: ShotImage.url(m.fileName))
        }
        for m in store.fileBacked {
            guard !m.fileName.hasPrefix("library-") else {
                try? FileManager.default.removeItem(at: ShotImage.url(m.fileName))
                continue
            }
            await adopt(m, store: store)
        }
    }
}
