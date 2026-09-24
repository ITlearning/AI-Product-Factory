import SwiftUI
import UIKit

/// PebbleCard 를 실제 이미지로 굽는다 — ImageRenderer 는 앱 타깃 전용(Shared 는 위젯·잠금화면 확장도 컴파일한다).
enum CardExporter {
    static let pointSize = CGSize(width: 1080 / 3, height: 1920 / 3)

    @MainActor
    static func render(dayKey: String, pebbleMoments: [Moment]) -> UIImage? {
        let renderer = ImageRenderer(content:
            PebbleCard(dayKey: dayKey, pebbleMoments: pebbleMoments)
                .frame(width: pointSize.width, height: pointSize.height))
        renderer.scale = 3
        guard let image = renderer.uiImage, !isBlank(image) else { return nil }
        return image
    }

    /// 한 달 한 줌 카드 — PebbleCard 와 같은 판형·같은 빈 이미지 판정을 쓴다.
    @MainActor
    static func renderHandful(month: String, pebbleGroups: [[Moment]]) -> UIImage? {
        let renderer = ImageRenderer(content:
            HandfulCard(month: month, pebbleGroups: pebbleGroups)
                .frame(width: pointSize.width, height: pointSize.height))
        renderer.scale = 3
        guard let image = renderer.uiImage, !isBlank(image) else { return nil }
        return image
    }

    /// PebbleView 의 drawingGroup/CoreImage 질감이 렌더 단계에서 통째로 비어버리는 경우를 잡는다.
    static func isBlank(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage, cg.width > 0, cg.height > 0 else { return true }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return true }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        for i in stride(from: 3, to: pixels.count, by: 4) where pixels[i] != 0 { return false }
        return true
    }
}
