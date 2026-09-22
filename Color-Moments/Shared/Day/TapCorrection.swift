import CoreGraphics

/// 사진 위 탭을 사진 안의 좌표로 옮기는 계산.
///
/// **레터박스가 함정이다.** `scaledToFit` 은 사진을 뷰 한가운데 맞춰 넣으므로 위아래(또는 좌우)에
/// 빈 띠가 생긴다. 뷰 좌표를 그대로 0~1 로 나누면 그 띠만큼 전부 밀려서, 누른 자리와 다른 색이
/// 잡힌다 — 조용히 틀리기 때문에 눈으로는 «색 추출이 이상하다»로 보인다.
public enum TapCorrection {

    /// 뷰 좌표계의 탭을 사진 안의 0~1 좌표(좌상단 원점)로. **사진 밖(빈 띠)을 누르면 nil.**
    ///
    /// nil 을 색으로 바꾸지 않는 것이 중요하다. 빈 띠를 눌렀는데 가장자리 색이 잡히면
    /// 사용자는 자기가 고른 적 없는 색을 갖게 된다.
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

    /// 0~1 좌표를 다시 뷰 좌표로. 누른 자리에 표식을 놓을 때 쓴다.
    /// 왕복이 어긋나면 표식이 누른 곳과 다른 데 찍혀 «내가 저기 눌렀나?» 가 된다.
    public static func viewPoint(normalized p: CGPoint, in viewSize: CGSize, imageSize: CGSize) -> CGPoint? {
        guard viewSize.width > 0, viewSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else { return nil }

        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let drawn = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGPoint(x: (viewSize.width - drawn.width) / 2 + p.x * drawn.width,
                       y: (viewSize.height - drawn.height) / 2 + p.y * drawn.height)
    }
}
