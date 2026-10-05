import CoreGraphics

/// 앱과 공방(workshop/embed)이 같은 함수를 컴파일한다 — 전처리가 다르면 학생이 다른 사진을 본다.
public enum WordImage {
    public static let side = 224

    public static func input(from image: CGImage) -> CGImage? {
        let scale = CGFloat(side) / CGFloat(min(image.width, image.height))
        let w = CGFloat(image.width) * scale, h = CGFloat(image.height) * scale
        guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: (CGFloat(side) - w) / 2, y: (CGFloat(side) - h) / 2, width: w, height: h))
        return ctx.makeImage()
    }
}
