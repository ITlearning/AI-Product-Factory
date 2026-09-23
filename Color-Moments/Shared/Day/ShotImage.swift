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

    public static func color(in image: UIImage, atNormalized point: CGPoint) -> ColorExtractor.RGB? {
        guard let oriented = orientedCIImage(image) else { return nil }
        return ColorExtractor.color(in: oriented, atNormalized: point)
    }

    public static func candidates(in image: UIImage, count: Int = 5) -> [String] {
        guard let oriented = orientedCIImage(image) else { return [] }
        return ColorExtractor.candidates(for: oriented, count: count).map(\.color.hex)
    }

    static func orientedCIImage(_ image: UIImage) -> CIImage? {
        guard let cg = image.cgImage else { return nil }
        return CIImage(cgImage: cg).oriented(exifOrientation(image.imageOrientation))
    }

    static func exifOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
