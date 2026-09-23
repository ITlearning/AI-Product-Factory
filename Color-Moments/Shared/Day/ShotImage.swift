import CoreImage
import ImageIO
import UIKit

public enum ShotImage {

    public static func url(_ fileName: String) -> URL {
        ShotStore.directory.appendingPathComponent(fileName)
    }

    public static func full(_ fileName: String) -> UIImage? {
        UIImage(contentsOfFile: url(fileName).path)
    }

    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 80
        c.totalCostLimit = 48 * 1024 * 1024
        return c
    }()

    private static func key(_ fileName: String, _ maxPixel: CGFloat) -> NSString {
        "\(fileName)@\(Int(maxPixel))" as NSString
    }

    public static func peek(_ fileName: String, maxPixel: CGFloat) -> UIImage? {
        cache.object(forKey: key(fileName, maxPixel))
    }

    @discardableResult
    public static func warm(_ fileName: String, maxPixel: CGFloat) -> UIImage? {
        if let hit = peek(fileName, maxPixel: maxPixel) { return hit }
        guard let img = thumbnail(fileName, maxPixel: maxPixel) else { return nil }
        cache.setObject(img, forKey: key(fileName, maxPixel),
                        cost: Int(img.size.width * img.size.height * 4))
        return img
    }

    public static func thumbnail(_ fileName: String, maxPixel: CGFloat = 400) -> UIImage? {
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
