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
            // 원본 그대로(PHImageManagerMaximumSize)는 파노라마 등에서 메모리를 과하게 쓴다 — 긴 변 4096 로 제한.
            targetSize = CGSize(width: 4096, height: 4096)
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

    // 같은 Moment 를 캡처 직후 흐름과 adoptAll 이 동시에 부를 수 있어, 저장이 두 번 나가지 않게 막는다.
    @MainActor private static var adopting: Set<Moment.ID> = []
    @MainActor private static var isAdoptingAll = false

    @MainActor
    static func adopt(_ m: Moment, store: DayStore) async {
        guard await adoptWithoutMapping(m, store: store) else { return }
        await CloudIDMapper.assignMissing(store: store)
    }

    /// adopt 의 본체 — cloudID 매핑은 호출부가 결정한다(adoptAll 은 루프 끝에 한 번만 하고 싶어서).
    @MainActor
    private static func adoptWithoutMapping(_ m: Moment, store: DayStore) async -> Bool {
        guard !adopting.contains(m.id) else { return false }
        // 전달받은 스냅샷은 낡았을 수 있다(다른 경로가 먼저 입양했거나 그사이 지워졌을 수 있음) —
        // 지금 저장소에서 다시 읽어 확인한다.
        guard let current = store.moments.first(where: { $0.id == m.id }), current.assetID == nil else { return false }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return false }

        adopting.insert(m.id)
        defer { adopting.remove(m.id) }

        let fileURL = ShotImage.url(current.fileName)
        let location = current.place.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        guard let assetID = await AssetSaver.save(fileURL: fileURL, creationDate: current.capturedAt, location: location) else {
            return false
        }

        // 저장은 성공했어도 그사이 다른 경로가 먼저 입양했을 수 있다 — store.adopt 가 true 일 때만 지운다.
        // false 면 파일은 그대로 두고 로그만 남긴다(고아 에셋이 사진 앱에 남지만, 로컬 파일이
        // 유일한 사본이 아니게 된 것뿐이라 다음 정리에서 자연히 지워진다).
        guard store.adopt(current.id, assetID: assetID) else {
            print("AssetAdopter: \(current.id) 는 저장 중 이미 입양돼 파일을 지우지 않음")
            return false
        }
        try? FileManager.default.removeItem(at: fileURL)
        return true
    }

    @MainActor
    static func adoptAll(store: DayStore) async {
        guard !isAdoptingAll else { return }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        isAdoptingAll = true
        defer { isAdoptingAll = false }

        // 사진첩에서 담은 옛 사본은 이미 assetID 가 있어 에셋으로 그려진다 — 남은 파일만 고아라 지운다.
        // 단, 그 assetID 가 실제로 사진 앱에서 찾아질 때만 지운다. 못 찾으면(기기 복원 등으로 assetID 가
        // 어긋난 경우) 파일을 남긴다 — ShotImage 가 에셋을 못 찾으면 파일로 폴백해 계속 그려진다.
        // 사본이 아예 없는 fileBacked 파일(assetID == nil)은 여기서 지우지 않는다 — 반드시 adopt 를 거쳐 저장한 뒤에만 지운다.
        let libraryBacked = store.moments.filter { $0.assetID != nil && $0.fileName.hasPrefix("library-") }
        if !libraryBacked.isEmpty {
            let ids = libraryBacked.compactMap(\.assetID)
            var found = Set<String>()
            PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
                .enumerateObjects { asset, _, _ in found.insert(asset.localIdentifier) }
            for m in libraryBacked where m.assetID.map(found.contains) == true {
                try? FileManager.default.removeItem(at: ShotImage.url(m.fileName))
            }
        }
        for m in store.fileBacked {
            _ = await adoptWithoutMapping(m, store: store)
        }
        await CloudIDMapper.assignMissing(store: store)
    }
}
