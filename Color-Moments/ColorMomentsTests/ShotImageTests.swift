import CoreImage
import UIKit
import XCTest
@testable import ColorMoments

/// **세로 사진에서 탭한 자리의 색이 맞게 잡히는가.**
///
/// 아이폰으로 세로로 찍은 사진은 픽셀이 가로로 저장되고 EXIF Orientation=6 이
/// 「그릴 때 90도 돌려라」를 들고 있다. `UIImage` 는 그 말을 듣고 화면에 세로로 그리지만
/// `CIImage(image:)` 는 **무시한다.** 그래서 보이는 좌표와 색을 뽑는 좌표가 90도 어긋난다.
///
/// 픽셀 데이터 자체는 멀쩡하고 화면도 멀쩡해 보여서, 증상은 「색 추출이 이상하다」로만 나타난다.
/// 실기기에 심어둔 테스트 사진이 전부 가로였던 탓에 한 번 놓쳤다.
final class ShotImageTests: XCTestCase {

    /// 왼쪽 절반 빨강 · 오른쪽 절반 파랑인 가로 그림(100x50).
    private func halfRedHalfBlue() throws -> CGImage {
        let w = 100, h = 50
        let ctx = try XCTUnwrap(CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w / 2, height: h))
        ctx.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        ctx.fill(CGRect(x: w / 2, y: 0, width: w / 2, height: h))
        return try XCTUnwrap(ctx.makeImage())
    }

    private func isRed(_ c: ColorExtractor.RGB?) -> Bool {
        guard let c else { return false }
        return c.r > 0.8 && c.b < 0.2
    }
    private func isBlue(_ c: ColorExtractor.RGB?) -> Bool {
        guard let c else { return false }
        return c.b > 0.8 && c.r < 0.2
    }

    /// 기준: 방향이 없으면 왼쪽이 빨강, 오른쪽이 파랑.
    func testUprightImageSamplesLeftAndRight() throws {
        let img = UIImage(cgImage: try halfRedHalfBlue(), scale: 1, orientation: .up)
        XCTAssertTrue(isRed(ShotImage.color(in: img, atNormalized: CGPoint(x: 0.25, y: 0.5))))
        XCTAssertTrue(isBlue(ShotImage.color(in: img, atNormalized: CGPoint(x: 0.75, y: 0.5))))
    }

    /// **핵심.** 같은 픽셀을 `.right`(EXIF 6, 아이폰 세로 촬영)로 달면 화면엔 90도 돌아 보인다 —
    /// 픽셀의 왼쪽(빨강)이 화면의 **위쪽**으로 간다. 색도 그 기준으로 잡혀야 한다.
    func testPortraitImageSamplesTopAndBottom() throws {
        let img = UIImage(cgImage: try halfRedHalfBlue(), scale: 1, orientation: .right)
        XCTAssertEqual(img.size, CGSize(width: 50, height: 100), "세로로 보이는 크기가 아니다")

        let top = ShotImage.color(in: img, atNormalized: CGPoint(x: 0.5, y: 0.25))
        let bottom = ShotImage.color(in: img, atNormalized: CGPoint(x: 0.5, y: 0.75))
        XCTAssertTrue(isRed(top), "화면 위쪽을 눌렀는데 빨강이 아니다 — EXIF 방향이 안 먹었다")
        XCTAssertTrue(isBlue(bottom), "화면 아래쪽을 눌렀는데 파랑이 아니다 — EXIF 방향이 안 먹었다")
    }

    /// 방향을 무시하던 옛 방식이 실제로 틀렸다는 것까지 못 박는다.
    /// 이 단언이 깨지면 «어긋나지 않는다»는 뜻이라 이 테스트 전체가 무의미해진 것이다.
    func testTheOldOrientationBlindWayWasActuallyWrong() throws {
        let img = UIImage(cgImage: try halfRedHalfBlue(), scale: 1, orientation: .right)
        let blind = CIImage(image: img)      // 예전 코드가 쓰던 것 — 방향을 안 읽는다
        let wrong = ColorExtractor.color(in: try XCTUnwrap(blind),
                                         atNormalized: CGPoint(x: 0.5, y: 0.25))
        XCTAssertFalse(isRed(wrong), "방향을 무시해도 같은 답이 나온다 — 이 버그는 재현되지 않는다")
    }

    /// 격자용 축소본도 방향이 적용돼 세로로 나와야 한다.
    func testThumbnailIsOrientedAndSmall() throws {
        let src = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "IMG_5005", withExtension: "jpg", subdirectory: "Fixtures"))
        let name = "thumbtest-\(UUID().uuidString).jpg"
        try Data(contentsOf: src).write(to: ShotImage.url(name))
        defer { try? FileManager.default.removeItem(at: ShotImage.url(name)) }

        let full = try XCTUnwrap(ShotImage.full(name))
        let thumb = try XCTUnwrap(ShotImage.thumbnail(name, maxPixel: 120))
        XCTAssertLessThanOrEqual(max(thumb.size.width, thumb.size.height), 120,
                                 "축소가 안 됐다 — 격자에 원본이 올라간다")
        XCTAssertEqual(thumb.size.width / thumb.size.height,
                       full.size.width / full.size.height, accuracy: 0.05,
                       "축소본 비율이 원본과 다르다 — 방향이 다르게 적용됐다")
    }
}
