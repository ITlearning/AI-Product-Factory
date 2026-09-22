import CoreImage
import ImageIO
import UIKit

/// 촬영물을 «화면에 보이는 대로» 다루기 위한 통로.
///
/// **EXIF 방향이 이 파일의 존재 이유다.** 아이폰으로 세로로 찍은 사진은 픽셀이 가로(4032×3024)로
/// 저장되고 EXIF Orientation=6 이 「그릴 때 90도 돌려라」를 들고 있다. `UIImage` 는 그걸 읽어
/// `imageOrientation` 에 담아두고 화면에도 세로로 그리지만, **`CIImage(image:)` 는 그 값을 무시한다.**
/// 그래서 «보이는 좌표»와 «색을 뽑는 좌표»가 90도 어긋나고, 탭 보정이 엉뚱한 자리 색을 집는다.
/// 픽셀만 보면 멀쩡해서 눈으로는 「색 추출이 이상하다」로만 보인다.
public enum ShotImage {

    public static func url(_ fileName: String) -> URL {
        ShotStore.directory.appendingPathComponent(fileName)
    }

    /// 원본 그대로. 사진을 크게 보여주는 자리(탭 보정)에서 쓴다.
    public static func full(_ fileName: String) -> UIImage? {
        UIImage(contentsOfFile: url(fileName).path)
    }

    /// 격자에 깔 작은 것. **원본을 통째로 올리지 않는다** — 12MP 짜리를 칸마다 디코드하면
    /// 사진 몇 장만으로 수백 MB가 된다.
    ///
    /// `kCGImageSourceCreateThumbnailWithTransform` 이 EXIF 방향까지 적용해서 내려주므로
    /// 격자에서도 세로 사진이 세로로 보인다.
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

    /// 화면에 보이는 좌표(0~1)로 색을 집는다. **방향을 적용한 뒤에 집는다.**
    public static func color(in image: UIImage, atNormalized point: CGPoint) -> ColorExtractor.RGB? {
        guard let oriented = orientedCIImage(image) else { return nil }
        return ColorExtractor.color(in: oriented, atNormalized: point)
    }

    /// 자동 후보. 통계라 방향과 무관하지만, 같은 그림을 보고 뽑도록 통로를 하나로 둔다.
    public static func candidates(in image: UIImage, count: Int = 5) -> [String] {
        guard let oriented = orientedCIImage(image) else { return [] }
        return ColorExtractor.candidates(for: oriented, count: count).map(\.color.hex)
    }

    /// `imageOrientation` 을 실제로 적용한 `CIImage`.
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
