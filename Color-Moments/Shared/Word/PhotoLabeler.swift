import CoreGraphics
import Vision

public enum PhotoLabeler {

    /// 확실한 라벨(정밀도 90%)에, 단어가 쓰는 라벨(vocabulary)만 한 단계 느슨하게(정밀도 70% · 확신도 0.15 이상) 더한다.
    /// 90% 만 쓰면 물가를 가까이 찍은 사진은 water(0.27)조차 떨어져 라벨이 빈다. 70% 로 다 풀면
    /// food 가 거의 모든 사진에 붙는다(확신도 0.01 미만) — 확신도 하한이 그걸 거른다(2026-10-01 실측).
    public static func labels(for image: CGImage, vocabulary: Set<String> = []) -> [String]? {
        let request = VNClassifyImageRequest()
        do { try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request]) } catch { return nil }
        return (request.results ?? [])
            .filter {
                $0.hasMinimumRecall(0.01, forPrecision: 0.9)
                    || (vocabulary.contains($0.identifier) && $0.confidence >= 0.15
                        && $0.hasMinimumRecall(0.01, forPrecision: 0.7))
            }
            .map(\.identifier)
    }

    public static func labels(for m: Moment, vocabulary: Set<String> = []) async -> [String]? {
        // thumbnail 은 EXIF 방향을 이미 적용한다 — 그래서 .up
        guard let image = await ShotImage.thumbnail(m, maxPixel: 600)?.cgImage, !Task.isCancelled else { return nil }
        return labels(for: image, vocabulary: vocabulary)
    }

    /// 연달아 찍은 같은 장면 — 특징값 거리가 이보다 가깝다. 같은 장면 두 장 0.14, 다른 사진끼리 0.79 이상(2026-10-01 실측).
    public static let sameSceneDistance: Float = 0.4

    public static func distance(_ a: CGImage, _ b: CGImage) -> Float? {
        let ra = VNGenerateImageFeaturePrintRequest(), rb = VNGenerateImageFeaturePrintRequest()
        do {
            try VNImageRequestHandler(cgImage: a, orientation: .up).perform([ra])
            try VNImageRequestHandler(cgImage: b, orientation: .up).perform([rb])
        } catch { return nil }
        guard let pa = ra.results?.first, let pb = rb.results?.first else { return nil }
        var d: Float = 0
        do { try pa.computeDistance(&d, to: pb) } catch { return nil }
        return d
    }

    public static func sameScene(_ a: Moment, _ b: Moment) async -> Bool {
        guard let ia = await ShotImage.thumbnail(a, maxPixel: 600)?.cgImage,
              let ib = await ShotImage.thumbnail(b, maxPixel: 600)?.cgImage,
              let d = distance(ia, ib) else { return false }
        return d < sameSceneDistance
    }
}
