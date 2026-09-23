import CoreGraphics

public enum TapCorrection {

    public static func normalized(tap: CGPoint, in viewSize: CGSize, imageSize: CGSize) -> CGPoint? {
        guard viewSize.width > 0, viewSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else { return nil }

        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let drawn = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: (viewSize.width - drawn.width) / 2,
                             y: (viewSize.height - drawn.height) / 2)

        let p = CGPoint(x: (tap.x - origin.x) / drawn.width,
                        y: (tap.y - origin.y) / drawn.height)
        guard (0...1).contains(p.x), (0...1).contains(p.y) else { return nil }
        return p
    }

    public static func viewPoint(normalized p: CGPoint, in viewSize: CGSize, imageSize: CGSize) -> CGPoint? {
        guard viewSize.width > 0, viewSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else { return nil }

        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let drawn = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGPoint(x: (viewSize.width - drawn.width) / 2 + p.x * drawn.width,
                       y: (viewSize.height - drawn.height) / 2 + p.y * drawn.height)
    }
}
