import Photos
import UIKit
import Vision

/// 최근 두 주 사진에서 풍경·감성 사진을 기기 안에서 골라 둔다. 사진은 기기 밖으로 나가지 않는다.
enum PhotoSuggester {

    struct Suggestion: Identifiable {
        let asset: PHAsset
        let image: UIImage
        let score: Double
        var id: String { asset.localIdentifier }
    }

    static let lookbackDays = 14
    static let maxScan = 200
    static let maxShown = 24
    static let thumbPixel: CGFloat = 360

    static func recentAssets(now: Date = Date()) -> [PHAsset] {
        let options = LibraryImporter.fetchOptions()
        let since = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: now) ?? now
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            options.predicate, NSPredicate(format: "creationDate >= %@", since as NSDate),
        ].compactMap { $0 })
        options.fetchLimit = maxScan
        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { a, _, _ in assets.append(a) }
        return assets
    }

    /// 최근 것부터 한 장씩 점수를 매겨 흘려보낸다 — 실용 사진·불러오지 못한 사진은 건너뛴다.
    static func suggestions(from assets: [PHAsset]) -> AsyncStream<Suggestion> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                for asset in assets {
                    guard !Task.isCancelled else { break }
                    guard let image = await thumbnail(asset), let cg = image.cgImage else { continue }
                    guard let score = await score(cg) else { continue }
                    continuation.yield(Suggestion(asset: asset, image: image, score: score))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func score(_ image: CGImage) async -> Double? {
        var overall: Float?
        var isUtility = false
        if let aesthetics = try? await CalculateImageAestheticsScoresRequest().perform(on: image) {
            overall = aesthetics.overallScore
            isUtility = aesthetics.isUtility
        }
        let labels = PhotoLabeler.labels(for: image) ?? []
        return SuggestionScore.combine(overall: overall, isUtility: isUtility, labels: labels)
    }

    private static func thumbnail(_ asset: PHAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        // 추천은 기기에 있는 썸네일로 충분하다 — iCloud 에서 원본을 끌어오면 200장에 한참 걸린다.
        options.isNetworkAccessAllowed = false
        let manager = PHImageManager.default()
        let size = CGSize(width: thumbPixel, height: thumbPixel)
        let fallback = DegradedHold()
        return await ImageRequestBridge.run(
            start: { deliver in
                manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill,
                                     options: options) { result, info in
                    let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if degraded && result != nil && info?[PHImageErrorKey] == nil { fallback.keep(result); return }
                    // 원본이 iCloud 에만 있으면 마지막엔 nil 이 온다 — 먼저 받은 저화질로라도 점수를 매긴다.
                    deliver(result ?? fallback.take())
                }
            },
            cancel: { manager.cancelImageRequest($0) }
        )
    }
}

private final class DegradedHold: @unchecked Sendable {
    private let lock = NSLock()
    private var image: UIImage?
    func keep(_ image: UIImage?) { lock.lock(); self.image = image; lock.unlock() }
    func take() -> UIImage? { lock.lock(); defer { lock.unlock() }; return image }
}
