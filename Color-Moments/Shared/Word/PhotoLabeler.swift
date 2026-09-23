import CoreGraphics
import Vision

public enum PhotoLabeler {

    public static func labels(for image: CGImage) -> [String]? {
        let request = VNClassifyImageRequest()
        do { try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request]) } catch { return nil }
        return (request.results ?? [])
            .filter { $0.hasMinimumRecall(0.01, forPrecision: 0.9) }
            .map(\.identifier)
    }

    public static func labels(for m: Moment) -> [String]? {
        // thumbnail 은 EXIF 방향을 이미 적용한다 — 그래서 .up
        guard let image = ShotImage.thumbnail(m, maxPixel: 600)?.cgImage else { return nil }
        return labels(for: image)
    }
}
