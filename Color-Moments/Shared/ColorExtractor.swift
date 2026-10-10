import CoreGraphics
import CoreImage
import Foundation

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

    static let darkCut = 0.25
    static let clusterCount = 5
    static let sampleSide = 96

    private static let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any
    ])

    public static func symbolicColor(for image: CIImage) -> RGB {
        let kept = afterDarkCut(sample(image))
        guard !kept.isEmpty else { return RGB(r: 0.5, g: 0.5, b: 0.5) }
        return histogramColors(kept, count: 1).first ?? RGB(r: 0.5, g: 0.5, b: 0.5)
    }

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

    static let levels = 12
    static let neighborRadius = 1

    static func histogramColors(_ px: [RGB], count: Int) -> [RGB] {
        guard !px.isEmpty, count > 0 else { return [] }
        let L = levels, R = neighborRadius
        func bin(_ p: RGB) -> (Int, Int, Int) {
            (min(L - 1, Int(p.r * Double(L))), min(L - 1, Int(p.g * Double(L))), min(L - 1, Int(p.b * Double(L))))
        }
        var w = [Double](repeating: 0, count: L * L * L)
        for p in px {
            let (r, g, b) = bin(p)
            let k = 0.35 + p.saturation
            w[(r * L + g) * L + b] += k
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

        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.idx < $1.idx }

        var picked: [RGB] = []
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
        }
        return picked
    }

    public static func palette(for image: CIImage) -> [PaletteColor] {
        let kept = afterDarkCut(sample(image))
        guard !kept.isEmpty else { return [PaletteColor(hex: RGB(r: 0.5, g: 0.5, b: 0.5).hex, share: 100)] }
        return palette(kept)
    }

    // histogramColors(count:) 는 고른 색의 이웃 빈을 다시 후보로 받아 같은 색을 여러 번 고른다 — 축마다 2칸 안은 건너뛴다.
    static func palette(_ px: [RGB], count: Int = 4) -> [PaletteColor] {
        let L = levels, R = neighborRadius
        func bin(_ p: RGB) -> (Int, Int, Int) {
            (min(L - 1, Int(p.r * Double(L))), min(L - 1, Int(p.g * Double(L))), min(L - 1, Int(p.b * Double(L))))
        }
        let bins = px.map(bin)
        let ks = px.map { 0.35 + $0.saturation }
        var w = [Double](repeating: 0, count: L * L * L)
        for (i, b) in bins.enumerated() { w[(b.0 * L + b.1) * L + b.2] += ks[i] }
        let total = ks.reduce(0, +)
        var scored: [(idx: Int, score: Double)] = []
        for r in 0..<L { for g in 0..<L { for b in 0..<L {
            var s = 0.0
            for dr in -R...R { for dg in -R...R { for db in -R...R {
                let rr = r + dr, gg = g + dg, bb = b + db
                if rr < 0 || gg < 0 || bb < 0 || rr >= L || gg >= L || bb >= L { continue }
                s += w[(rr * L + gg) * L + bb]
            }}}
            if s > 0 { scored.append((idx: (r * L + g) * L + b, score: s)) }
        }}}
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.idx < $1.idx }

        var picked: [(rgb: RGB, weight: Double)] = []
        var used = Set<Int>(), centers: [(Int, Int, Int)] = []
        for cand in scored {
            guard picked.count < count else { break }
            if used.contains(cand.idx) { continue }
            let c = (cand.idx / (L * L), (cand.idx / L) % L, cand.idx % L)
            if centers.contains(where: { abs($0.0 - c.0) <= 2 && abs($0.1 - c.1) <= 2 && abs($0.2 - c.2) <= 2 }) { continue }
            var n = 0.0, sr = 0.0, sg = 0.0, sb = 0.0
            for (i, b) in bins.enumerated() {
                guard abs(b.0 - c.0) <= R, abs(b.1 - c.1) <= R, abs(b.2 - c.2) <= R else { continue }
                let p = px[i], k = ks[i]
                sr += p.r * k; sg += p.g * k; sb += p.b * k; n += k
                used.insert((b.0 * L + b.1) * L + b.2)
            }
            guard n > 0 else { continue }
            centers.append(c)
            picked.append((RGB(r: sr / n, g: sg / n, b: sb / n), n / total))
        }

        var merged: [(rgb: RGB, weight: Double)] = []
        for p in picked {
            if let i = merged.firstIndex(where: { distance($0.rgb, p.rgb) < 0.10 || channelGap($0.rgb, p.rgb) <= 25.0 / 255 }) { merged[i].weight += p.weight }
            else { merged.append(p) }
        }
        let sum = merged.map(\.weight).reduce(0, +)
        var shares = merged.map { Int(($0.weight / sum * 100).rounded()) }
        if !shares.isEmpty { shares[0] += 100 - shares.reduce(0, +) }
        let colors = zip(merged, shares).map { PaletteColor(hex: $0.rgb.hex, share: $1) }
        guard let head = colors.first else { return [] }
        return [head] + colors.dropFirst().sorted { $0.share > $1.share }
    }

    // 유클리드 거리로는 안 합쳐지는 무채색 근처 두 색(채널 차 24)이 조약돌에서 한 색으로 보인다.
    static func channelGap(_ a: RGB, _ b: RGB) -> Double { max(abs(a.r - b.r), abs(a.g - b.g), abs(a.b - b.b)) }

    static func distance(_ a: RGB, _ b: RGB) -> Double {
        ((a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b)).squareRoot()
    }
}
