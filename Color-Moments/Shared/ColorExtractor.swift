import CoreGraphics
import CoreImage
import Foundation

/// 사진 1장에서 상징색 1개를 뽑는다.
///
/// 채택된 방식은 **어두운 하위 25%를 버린 뒤 고정 격자 히스토그램의 최대 칸**이다.
/// 실루엣·그림자는 색 정보가 아니라 프레임이므로 버린다.
/// 기각된 방식과 그 이유는 `docs/designs/color-moments.md` 「색 추출 실측」에 기록돼 있다.
///
/// **k-means 를 쓰지 않는 이유**: 같은 사진이 샘플 해상도에 따라 다른 색을 냈다
/// (2026-09-22 실측: IMG_5471 이 96px 에서 #737168, 64px 에서 #98978D — 38/255 차이).
/// 시드를 밝기 분위수로 고쳐도 반복이 다른 국소최소로 수렴해 11장 중 2장이 흔들렸다.
/// 고정 격자는 시드도 반복도 없어 **구조적으로 결정론**이다. 4개 해상도에서 11/11 이 6/255 이내.
/// 대가: IMG_5005(벚꽃)에서 하늘 대신 나뭇가지를 고른다. 그 사진의 정답(분홍)은 어차피
/// 어느 자동 방식으로도 안 나오므로 탭 보정으로 푼다.
///
/// 자동 추출에는 상한이 있다. 벚꽃처럼 사람이 「분홍」으로 보는 색이 픽셀에 없는 경우가 있어서,
/// `color(in:atNormalized:)` 로 사용자가 한 탭으로 고칠 수 있게 한다.
public enum ColorExtractor {

    public struct RGB: Equatable, Sendable {
        public var r: Double, g: Double, b: Double
        public init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

        public var hex: String {
            String(format: "#%02X%02X%02X",
                   Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
        }
        var value: Double { max(r, g, b) }
        var saturation: Double { let mx = max(r, g, b), mn = min(r, g, b); return mx <= 0 ? 0 : (mx - mn) / mx }
    }

    public struct Candidate: Sendable {
        public let color: RGB
        /// 0~1. 어둠컷 이후 픽셀 중 이 클러스터가 차지하는 비율.
        public let weight: Double
    }

    /// 어둠컷 비율. 25%는 실측으로 고른 값이다(50%는 벚꽃 사진에서 꽃을 통째로 잘라냈다).
    static let darkCut = 0.25
    static let clusterCount = 5
    static let sampleSide = 96

    private static let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any
    ])

    // MARK: 공개 API

    /// 자동 추출된 상징색. 같은 입력은 항상 같은 값을 낸다.
    public static func symbolicColor(for image: CIImage) -> RGB {
        let kept = afterDarkCut(sample(image))
        guard !kept.isEmpty else { return RGB(r: 0.5, g: 0.5, b: 0.5) }
        return histogramColors(kept, count: 1).first ?? RGB(r: 0.5, g: 0.5, b: 0.5)
    }

    /// 탭 보정 UI가 보여줄 후보들. 무게 내림차순. 이것도 결정론적이다.
    public static func candidates(for image: CIImage, count: Int = 5) -> [Candidate] {
        let kept = afterDarkCut(sample(image))
        guard !kept.isEmpty else { return [] }
        return histogramColors(kept, count: count, wantWeights: true).enumerated().map { i, c in
            Candidate(color: c, weight: lastWeights.indices.contains(i) ? lastWeights[i] : 0)
        }
    }

    /// 사용자가 사진 위를 탭했을 때. point 는 0~1 정규화 좌표(좌상단 원점).
    /// 단일 픽셀은 노이즈에 흔들리므로 작은 영역의 평균을 쓴다.
    public static func color(in image: CIImage, atNormalized point: CGPoint) -> RGB {
        let e = image.extent
        let side = min(e.width, e.height) * 0.04     // 짧은 변의 4%
        let cx = e.origin.x + e.width * point.x
        // CIImage 는 좌하단 원점이므로 y 를 뒤집는다
        let cy = e.origin.y + e.height * (1 - point.y)
        let rect = CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side).intersection(e)
        guard !rect.isNull, rect.width >= 1, rect.height >= 1 else { return symbolicColor(for: image) }
        return average(image, in: rect)
    }

    // MARK: 내부

    static func afterDarkCut(_ px: [RGB]) -> [RGB] {
        let sorted = px.sorted { $0.value < $1.value }
        let start = Int(Double(sorted.count) * darkCut)
        return Array(sorted[min(start, sorted.count - 1)...])
    }

    static func sample(_ image: CIImage, side: Int = sampleSide) -> [RGB] {
        let e = image.extent
        guard e.width > 0, e.height > 0 else { return [] }
        let s = min(Double(side) / e.width, Double(side) / e.height)
        let small = image.transformed(by: CGAffineTransform(scaleX: s, y: s))
        let w = Int(small.extent.width), h = Int(small.extent.height)
        guard w > 0, h > 0 else { return [] }
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        context.render(small, toBitmap: &buf, rowBytes: w * 4,
                       bounds: CGRect(x: small.extent.origin.x, y: small.extent.origin.y,
                                      width: CGFloat(w), height: CGFloat(h)),
                       format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return stride(from: 0, to: buf.count, by: 4).map {
            RGB(r: Double(buf[$0]) / 255, g: Double(buf[$0 + 1]) / 255, b: Double(buf[$0 + 2]) / 255)
        }
    }

    static func average(_ image: CIImage, in rect: CGRect) -> RGB {
        guard let f = CIFilter(name: "CIAreaAverage") else { return RGB(r: 0.5, g: 0.5, b: 0.5) }
        f.setValue(image, forKey: kCIInputImageKey)
        f.setValue(CIVector(cgRect: rect), forKey: "inputExtent")
        guard let out = f.outputImage else { return RGB(r: 0.5, g: 0.5, b: 0.5) }
        var px = [UInt8](repeating: 0, count: 4)
        context.render(out, toBitmap: &px, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return RGB(r: Double(px[0]) / 255, g: Double(px[1]) / 255, b: Double(px[2]) / 255)
    }

    /// 고정 격자 히스토그램. 시드도 반복도 없으므로 같은 입력은 항상 같은 답을 낸다.
    ///
    /// 각 픽셀을 `levels`^3 격자에 넣되 채도로 가중한다(칙칙한 큰 덩어리보다 선명한 쪽이 사진의 색에 가깝다).
    /// 인접 칸까지 합산해 그라데이션으로 쪼개진 같은 색을 되붙이고, 최종값은 그 범위 안 실제 픽셀의
    /// 가중 평균이라 양자화 오차가 남지 않는다.
    static let levels = 12
    static let neighborRadius = 1
    nonisolated(unsafe) private static var lastWeights: [Double] = []

    static func histogramColors(_ px: [RGB], count: Int, wantWeights: Bool = false) -> [RGB] {
        guard !px.isEmpty, count > 0 else { return [] }
        let L = levels, R = neighborRadius
        func bin(_ p: RGB) -> (Int, Int, Int) {
            (min(L - 1, Int(p.r * Double(L))), min(L - 1, Int(p.g * Double(L))), min(L - 1, Int(p.b * Double(L))))
        }
        var w = [Double](repeating: 0, count: L * L * L)
        var total = 0.0
        for p in px {
            let (r, g, b) = bin(p)
            let k = 0.35 + p.saturation
            w[(r * L + g) * L + b] += k
            total += k
        }
        var scored: [(idx: Int, score: Double)] = []
        scored.reserveCapacity(L * L * L)
        for r in 0..<L { for g in 0..<L { for b in 0..<L {
            var s = 0.0
            for dr in -R...R { for dg in -R...R { for db in -R...R {
                let rr = r + dr, gg = g + dg, bb = b + db
                if rr < 0 || gg < 0 || bb < 0 || rr >= L || gg >= L || bb >= L { continue }
                s += w[(rr * L + gg) * L + bb]
            }}}
            if s > 0 { scored.append((idx: (r * L + g) * L + b, score: s)) }
        }}}
        // 점수가 같아도 순서가 고정되도록 인덱스를 2차 키로 쓴다
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.idx < $1.idx }

        var picked: [RGB] = []
        var weights: [Double] = []
        var used = Set<Int>()
        for cand in scored {
            guard picked.count < count else { break }
            if used.contains(cand.idx) { continue }
            let br = cand.idx / (L * L), bg = (cand.idx / L) % L, bb = cand.idx % L
            var n = 0.0, sr = 0.0, sg = 0.0, sb = 0.0
            for p in px {
                let (r, g, b) = bin(p)
                guard abs(r - br) <= R, abs(g - bg) <= R, abs(b - bb) <= R else { continue }
                let k = 0.35 + p.saturation
                sr += p.r * k; sg += p.g * k; sb += p.b * k; n += k
                used.insert((r * L + g) * L + b)
            }
            guard n > 0 else { continue }
            picked.append(RGB(r: sr / n, g: sg / n, b: sb / n))
            weights.append(total > 0 ? n / total : 0)
        }
        if wantWeights { lastWeights = weights }
        return picked
    }
}
