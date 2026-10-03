import CoreGraphics
import Foundation

// 앱 타깃(UIKit)에만 있는 것의 자리. 단어 판정 코드는 이것들을 부르지 않는다.
final class SharedBundleMarker {}

struct StubImage { let cgImage: CGImage? }

enum ShotImage {
    static func thumbnail(_ m: Moment, maxPixel: CGFloat = 400) async -> StubImage? { nil }
}
