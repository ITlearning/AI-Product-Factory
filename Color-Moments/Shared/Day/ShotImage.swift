import CoreImage
import ImageIO
import Observation
import UIKit

/// 사진 앱 접근을 대신해주는 구멍 — Shared 는 Photos 를 모른다, 앱 타깃이 꽂는다.
/// 취소되면 요청을 거두고 nil 을 돌려준다.
public protocol AssetImageSource: Sendable {
    func image(assetID: String, maxPixel: CGFloat) async -> UIImage?
}

public enum ShotImage {

    /// 앱이 시작할 때 꽂는다. 기본 nil 이면 모든 Moment 가 파일 판으로 그려진다.
    public static var assetSource: AssetImageSource?

    /// 사진 앱 변경·assetID 재배정을 알리는 세대 번호 — 값이 바뀌면 떠 있는 뷰가 `.task(id:)` 로 다시 요청한다.
    /// 정확히 어떤 자산인지 모르면(사진 앱 전체 변경 신호 등) `global` 을, 알면 그 assetID 만 올린다.
    @Observable
    public final class Generation {
        public private(set) var global = 0
        public private(set) var byAsset: [String: Int] = [:]

        public func bump(assetID: String? = nil) {
            if let assetID {
                byAsset[assetID, default: 0] += 1
            } else {
                global += 1
            }
        }

        public func value(for assetID: String?) -> Int {
            global + (assetID.flatMap { byAsset[$0] } ?? 0)
        }
    }

    public static let generation = Generation()

    public static func url(_ fileName: String) -> URL {
        ShotStore.directory.appendingPathComponent(fileName)
    }

    // MARK: - Moment 판 (공개) — assetID 가 있고 assetSource 가 꽂혀 있으면 에셋, 아니면 파일

    public static func full(_ m: Moment) async -> UIImage? {
        if let assetID = m.assetID, let source = assetSource,
           let img = await source.image(assetID: assetID, maxPixel: .greatestFiniteMagnitude) {
            return img
        }
        guard !Task.isCancelled else { return nil }
        // 에셋을 못 찾았거나(기기 복원 등으로 assetID 가 어긋남) assetSource 가 아직 안 꽂혔으면
        // 파일로 한 번 더 시도한다 — fileName 은 옛 기록이거나, 아직 지우지 않은 library-* 잔여 파일일 수 있다.
        return full(m.fileName)
    }

    /// 썸네일은 스크롤로 한꺼번에 몰린다 — 사진 앱 요청·파일 디코딩을 이만큼만 동시에 돌린다.
    static let thumbnailGate = AsyncGate(limit: 6)

    public static func thumbnail(_ m: Moment, maxPixel: CGFloat = 400) async -> UIImage? {
        await thumbnailGate.run { await ungatedThumbnail(m, maxPixel: maxPixel) } ?? nil
    }

    private static func ungatedThumbnail(_ m: Moment, maxPixel: CGFloat) async -> UIImage? {
        guard !Task.isCancelled else { return nil }
        if let assetID = m.assetID, let source = assetSource,
           let img = await source.image(assetID: assetID, maxPixel: maxPixel) {
            return img
        }
        guard !Task.isCancelled else { return nil }
        return thumbnail(m.fileName, maxPixel: maxPixel)
    }

    public static func peek(_ m: Moment, maxPixel: CGFloat) -> UIImage? {
        peek(cacheID(m), maxPixel: maxPixel)
    }

    /// 뜬 채로 못 받았을 때 다시 물어볼 간격 — iCloud 사진이 늦게 내려오는 창.
    public static let retryDelaysNanoseconds: [UInt64] = [2_000_000_000, 5_000_000_000, 15_000_000_000]

    /// assetID 가 있는데(사진 앱에 있어야 하는데) 못 받았으면 `delays` 만큼 뒤에 다시 시도한다.
    /// 취소되면(뷰가 사라지면) 바로 멈춘다. 캐시에 이미 있으면 warm() 이 그대로 돌려주고 재시도로 안 들어간다.
    public static func warmWithRetry(_ m: Moment, maxPixel: CGFloat,
                                     delays: [UInt64] = retryDelaysNanoseconds) async -> UIImage? {
        if let img = await warm(m, maxPixel: maxPixel) { return img }
        guard m.assetID != nil else { return nil }
        for delay in delays {
            guard !Task.isCancelled else { return nil }
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return nil }
            if let img = await warm(m, maxPixel: maxPixel) { return img }
        }
        return nil
    }

    /// full(_:) 의 재시도판 — 원본판은 캐시하지 않으므로 매번 다시 묻는다.
    public static func fullWithRetry(_ m: Moment, delays: [UInt64] = retryDelaysNanoseconds) async -> UIImage? {
        if let img = await full(m) { return img }
        guard m.assetID != nil else { return nil }
        for delay in delays {
            guard !Task.isCancelled else { return nil }
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return nil }
            if let img = await full(m) { return img }
        }
        return nil
    }

    @discardableResult
    public static func warm(_ m: Moment, maxPixel: CGFloat) async -> UIImage? {
        let id = cacheID(m)
        if let hit = peek(id, maxPixel: maxPixel) { return hit }
        guard let img = await thumbnail(m, maxPixel: maxPixel) else { return nil }
        cache.setObject(img, forKey: key(id, maxPixel),
                        cost: Int(img.size.width * img.size.height * 4))
        return img
    }

    private static func cacheID(_ m: Moment) -> String { m.assetID ?? m.fileName }

    // MARK: - fileName 판 (내부용 — Moment 판이 파일 백업일 때만 부른다)

    static func full(_ fileName: String) -> UIImage? {
        UIImage(contentsOfFile: url(fileName).path)
    }

    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 80
        c.totalCostLimit = 48 * 1024 * 1024
        return c
    }()

    private static func key(_ id: String, _ maxPixel: CGFloat) -> NSString {
        "\(id)@\(Int(maxPixel))" as NSString
    }

    static func peek(_ id: String, maxPixel: CGFloat) -> UIImage? {
        cache.object(forKey: key(id, maxPixel))
    }

    @discardableResult
    static func warm(_ fileName: String, maxPixel: CGFloat) -> UIImage? {
        if let hit = peek(fileName, maxPixel: maxPixel) { return hit }
        guard let img = thumbnail(fileName, maxPixel: maxPixel) else { return nil }
        cache.setObject(img, forKey: key(fileName, maxPixel),
                        cost: Int(img.size.width * img.size.height * 4))
        return img
    }

    static func thumbnail(_ fileName: String, maxPixel: CGFloat = 400) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url(fileName) as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}
