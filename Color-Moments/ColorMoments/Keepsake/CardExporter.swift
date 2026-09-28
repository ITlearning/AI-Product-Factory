import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// PebbleCard 를 실제 이미지로 굽는다 — ImageRenderer 는 앱 타깃 전용(Shared 는 위젯·잠금화면 확장도 컴파일한다).
enum CardExporter {
    static let pointSize = PebbleCardLayout.canvas
    static let photoPixels: CGFloat = 1600

    @MainActor
    static func render(dayKey: String, pebbleMoments: [Moment], face: Moment? = nil, photo: UIImage? = nil) -> UIImage? {
        renderRaw(dayKey: dayKey, pebbleMoments: pebbleMoments, face: face, photo: photo)
            .flatMap { isBlank($0, region: blankRegion(photo: photo)) ? nil : $0 }
    }

    /// 카드용 사진 — 사진 앱 에셋, 없으면 파일. 받은 기록은 nil(색 면으로 그린다).
    static func cardPhoto(_ m: Moment) async -> UIImage? {
        await ShotImage.thumbnail(m, maxPixel: photoPixels)
    }

    static func blankRegion(photo: UIImage?) -> CGRect {
        PebbleCardLayout.blankRegion(aspect: PebbleCardLayout.aspect(of: photo))
    }

    /// 한 달 한 줌 카드 — PebbleCard 와 같은 판형·같은 빈 카드 판정을 쓴다.
    @MainActor
    static func renderHandful(month: String, today: String = Moment.dayKey(for: Date()),
                              pebbleGroups: [[Moment]]) -> UIImage? {
        renderHandfulRaw(month: month, today: today, pebbleGroups: pebbleGroups).flatMap { isBlank($0) ? nil : $0 }
    }

    /// 빈 판정 전 렌더 — ImageRenderer 는 메인 전용이라 이 부분만 메인에 남기고 나머지는 prepare 로 넘긴다.
    @MainActor
    static func renderRaw(dayKey: String, pebbleMoments: [Moment], face: Moment? = nil, photo: UIImage? = nil) -> UIImage? {
        guard !pebbleMoments.isEmpty else { return nil }
        return bake(PebbleCard(dayKey: dayKey, pebbleMoments: pebbleMoments, face: face, photo: photo))
    }

    @MainActor
    static func renderHandfulRaw(month: String, today: String = Moment.dayKey(for: Date()),
                                 pebbleGroups: [[Moment]]) -> UIImage? {
        guard pebbleGroups.contains(where: { !$0.isEmpty }) else { return nil }
        return bake(HandfulCard(month: month, pebbleGroups: pebbleGroups, today: today))
    }

    @MainActor
    private static func bake<V: View>(_ card: V) -> UIImage? {
        let renderer = ImageRenderer(content: card.frame(width: pointSize.width, height: pointSize.height))
        renderer.scale = 3
        return renderer.uiImage
    }

    /// 건넬 준비가 끝난 카드 — PNG 를 미리 구워 둔다(ShareLink(item: Image) 는 건네기를 누르는 순간 메인에서 굽는다).
    struct Prepared: @unchecked Sendable {
        let image: UIImage
        let png: CardPNG
        let preview: UIImage
    }

    /// 빈 판정·PNG 인코딩·미리보기 축소는 메인 밖에서. 비었거나 인코딩이 실패하면 nil.
    static func prepare(_ image: UIImage?, region: CGRect = pebbleRegion) async -> Prepared? {
        guard let image else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> Prepared? in
            guard !isBlank(image, region: region), let data = image.pngData() else { return nil }
            let side = CGSize(width: pointSize.width / 2, height: pointSize.height / 2)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            let preview = UIGraphicsImageRenderer(size: side, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: side))
            }
            return Prepared(image: image, png: CardPNG(data: data), preview: preview)
        }.value
    }

    /// HandfulCard 의 돌이 모이는 가운데 영역(0...1) — PebbleCard 는 사진마다 달라 PebbleCardLayout.blankRegion 을 쓴다.
    static let pebbleRegion = CGRect(x: 0.3, y: 0.25, width: 0.4, height: 0.3)

    struct RegionStats: Equatable {
        let meanDiffFromBackground: Double
        let lumaVariance: Double
    }

    static func regionStats(_ image: UIImage, region: CGRect = pebbleRegion) -> RegionStats? {
        guard let cg = image.cgImage, cg.width > 0, cg.height > 0 else { return nil }
        let w = cg.width, h = cg.height
        let x0 = Int(region.minX * Double(w)), x1 = Int(region.maxX * Double(w))
        let y0 = Int(region.minY * Double(h)), y1 = Int(region.maxY * Double(h))
        // 전체(1080×1920)를 풀지 않고 배경 한 점과 조약돌 자리만 잘라 푼다 — 같은 픽셀을 본다.
        guard let corner = pixels(cg, CGRect(x: 1, y: 1, width: 1, height: 1)), x1 > x0, y1 > y0,
              let area = pixels(cg, CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)) else { return nil }
        let bg = (Double(corner.data[0]), Double(corner.data[1]), Double(corner.data[2]))
        var n = 0.0, diff = 0.0, sum = 0.0, sumSq = 0.0
        for y in stride(from: 0, to: area.height, by: 2) {
            for x in stride(from: 0, to: area.width, by: 2) {
                let i = (y * area.width + x) * 4
                let (r, g, b) = (Double(area.data[i]), Double(area.data[i + 1]), Double(area.data[i + 2]))
                diff += (abs(r - bg.0) + abs(g - bg.1) + abs(b - bg.2)) / 3
                let luma = 0.299 * r + 0.587 * g + 0.114 * b
                sum += luma; sumSq += luma * luma; n += 1
            }
        }
        guard n > 0 else { return nil }
        let mean = sum / n
        return RegionStats(meanDiffFromBackground: diff / n, lumaVariance: max(0, sumSq / n - mean * mean))
    }

    private static func pixels(_ cg: CGImage, _ rect: CGRect) -> (data: [UInt8], width: Int, height: Int)? {
        guard let cropped = cg.cropping(to: rect) else { return nil }
        let w = cropped.width, h = cropped.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = data.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return drawn ? (data, w, h) : nil
    }

    /// 조약돌 자리가 배경과 같거나 한 색으로 균일하면 빈 카드 — PebbleView 의 drawingGroup/CoreImage 질감이
    /// 렌더 단계에서 비어버리는 경우를 잡는다(배경이 불투명해 알파만 봐서는 못 잡는다).
    static func isBlank(_ image: UIImage, region: CGRect = pebbleRegion) -> Bool {
        guard let s = regionStats(image, region: region) else { return true }
        // 실측(시뮬레이터): 돌 있는 카드 분산 ≈ 500~2000, 돌 빠진 배경 그라데이션만 ≈ 6.
        return s.meanDiffFromBackground < 6 || s.lumaVariance < 50
    }
}

/// 카드 PNG 를 그대로 건넨다 — 이미 구운 데이터라 건네기를 눌러도 다시 인코딩하지 않는다.
struct CardPNG: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
    }
}
