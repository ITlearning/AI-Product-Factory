import CoreImage
import ImageIO
import UIKit

/// 사진 앱 접근을 대신해주는 구멍 — Shared 는 Photos 를 모른다, 앱 타깃이 꽂는다.
public protocol AssetImageSource: Sendable {
    func image(assetID: String, maxPixel: CGFloat) -> UIImage?
}

public enum ShotImage {

    /// 앱이 시작할 때 꽂는다. 기본 nil 이면 모든 Moment 가 파일 판으로 그려진다.
    public static var assetSource: AssetImageSource?

    public static func url(_ fileName: String) -> URL {
        ShotStore.directory.appendingPathComponent(fileName)
    }

    // MARK: - Moment 판 (공개) — assetID 가 있고 assetSource 가 꽂혀 있으면 에셋, 아니면 파일

    public static func full(_ m: Moment) -> UIImage? {
        if let assetID = m.assetID, let source = assetSource {
            return source.image(assetID: assetID, maxPixel: .greatestFiniteMagnitude)
        }
        return full(m.fileName)
    }

    public static func thumbnail(_ m: Moment, maxPixel: CGFloat = 400) -> UIImage? {
        if let assetID = m.assetID, let source = assetSource {
            return source.image(assetID: assetID, maxPixel: maxPixel)
        }
        return thumbnail(m.fileName, maxPixel: maxPixel)
    }

    public static func peek(_ m: Moment, maxPixel: CGFloat) -> UIImage? {
        peek(cacheID(m), maxPixel: maxPixel)
    }

    @discardableResult
    public static func warm(_ m: Moment, maxPixel: CGFloat) -> UIImage? {
        let id = cacheID(m)
        if let hit = peek(id, maxPixel: maxPixel) { return hit }
        guard let img = thumbnail(m, maxPixel: maxPixel) else { return nil }
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
