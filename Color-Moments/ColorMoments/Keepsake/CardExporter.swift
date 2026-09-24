import SwiftUI
import UIKit

/// PebbleCard 를 실제 이미지로 굽는다 — ImageRenderer 는 앱 타깃 전용(Shared 는 위젯·잠금화면 확장도 컴파일한다).
enum CardExporter {
    static let pointSize = CGSize(width: 1080 / 3, height: 1920 / 3)

    @MainActor
    static func render(dayKey: String, pebbleMoments: [Moment]) -> UIImage? {
        guard !pebbleMoments.isEmpty else { return nil }
        let renderer = ImageRenderer(content:
            PebbleCard(dayKey: dayKey, pebbleMoments: pebbleMoments)
                .frame(width: pointSize.width, height: pointSize.height))
        renderer.scale = 3
        guard let image = renderer.uiImage, !isBlank(image) else { return nil }
        return image
    }

    /// 한 달 한 줌 카드 — PebbleCard 와 같은 판형·같은 빈 카드 판정을 쓴다.
    @MainActor
    static func renderHandful(month: String, today: String = Moment.dayKey(for: Date()),
                              pebbleGroups: [[Moment]]) -> UIImage? {
        guard pebbleGroups.contains(where: { !$0.isEmpty }) else { return nil }
        let renderer = ImageRenderer(content:
            HandfulCard(month: month, pebbleGroups: pebbleGroups, today: today)
                .frame(width: pointSize.width, height: pointSize.height))
        renderer.scale = 3
        guard let image = renderer.uiImage, !isBlank(image) else { return nil }
        return image
    }

    /// 조약돌이 놓이는 가운데 영역(0...1 비율) — PebbleCard 는 돌이 세로 가운데보다 조금 위, HandfulCard 는 위 72% 가운데.
    static let pebbleRegion = CGRect(x: 0.3, y: 0.25, width: 0.4, height: 0.3)

    struct RegionStats: Equatable {
        let meanDiffFromBackground: Double
        let lumaVariance: Double
    }

    static func regionStats(_ image: UIImage, region: CGRect = pebbleRegion) -> RegionStats? {
        guard let cg = image.cgImage, cg.width > 0, cg.height > 0 else { return nil }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        func rgb(_ x: Int, _ y: Int) -> (Double, Double, Double) {
            let i = (y * w + x) * 4
            return (Double(pixels[i]), Double(pixels[i + 1]), Double(pixels[i + 2]))
        }
        let bg = rgb(1, 1)
        let x0 = Int(region.minX * Double(w)), x1 = Int(region.maxX * Double(w))
        let y0 = Int(region.minY * Double(h)), y1 = Int(region.maxY * Double(h))
        var n = 0.0, diff = 0.0, sum = 0.0, sumSq = 0.0
        for y in stride(from: y0, to: y1, by: 2) {
            for x in stride(from: x0, to: x1, by: 2) {
                let (r, g, b) = rgb(x, y)
                diff += (abs(r - bg.0) + abs(g - bg.1) + abs(b - bg.2)) / 3
                let luma = 0.299 * r + 0.587 * g + 0.114 * b
                sum += luma; sumSq += luma * luma; n += 1
            }
        }
        guard n > 0 else { return nil }
        let mean = sum / n
        return RegionStats(meanDiffFromBackground: diff / n, lumaVariance: max(0, sumSq / n - mean * mean))
    }

    /// 가운데 조약돌 자리가 배경과 같거나 한 색으로 균일하면 빈 카드 — PebbleView 의 drawingGroup/CoreImage 질감이
    /// 렌더 단계에서 비어버리는 경우를 잡는다(배경이 불투명해 알파만 봐서는 못 잡는다).
    static func isBlank(_ image: UIImage) -> Bool {
        guard let s = regionStats(image) else { return true }
        // 실측(시뮬레이터): 돌 있는 카드 분산 ≈ 500~2000, 돌 빠진 배경 그라데이션만 ≈ 6.
        return s.meanDiffFromBackground < 6 || s.lumaVariance < 50
    }
}
