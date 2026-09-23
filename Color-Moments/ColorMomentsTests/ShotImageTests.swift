import CoreImage
import UIKit
import XCTest
@testable import ColorMoments

final class ShotImageTests: XCTestCase {

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

    func testUprightImageSamplesLeftAndRight() throws {
        let img = UIImage(cgImage: try halfRedHalfBlue(), scale: 1, orientation: .up)
        XCTAssertTrue(isRed(ShotImage.color(in: img, atNormalized: CGPoint(x: 0.25, y: 0.5))))
        XCTAssertTrue(isBlue(ShotImage.color(in: img, atNormalized: CGPoint(x: 0.75, y: 0.5))))
    }

    func testPortraitImageSamplesTopAndBottom() throws {
        let img = UIImage(cgImage: try halfRedHalfBlue(), scale: 1, orientation: .right)
        XCTAssertEqual(img.size, CGSize(width: 50, height: 100), "세로로 보이는 크기가 아니다")

        let top = ShotImage.color(in: img, atNormalized: CGPoint(x: 0.5, y: 0.25))
        let bottom = ShotImage.color(in: img, atNormalized: CGPoint(x: 0.5, y: 0.75))
        XCTAssertTrue(isRed(top), "화면 위쪽을 눌렀는데 빨강이 아니다 — EXIF 방향이 안 먹었다")
        XCTAssertTrue(isBlue(bottom), "화면 아래쪽을 눌렀는데 파랑이 아니다 — EXIF 방향이 안 먹었다")
    }

    func testTheOldOrientationBlindWayWasActuallyWrong() throws {
        let img = UIImage(cgImage: try halfRedHalfBlue(), scale: 1, orientation: .right)
        let blind = CIImage(image: img)
        let wrong = ColorExtractor.color(in: try XCTUnwrap(blind),
                                         atNormalized: CGPoint(x: 0.5, y: 0.25))
        XCTAssertFalse(isRed(wrong), "방향을 무시해도 같은 답이 나온다 — 이 버그는 재현되지 않는다")
    }

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

final class ShotImageCacheTests: XCTestCase {

    private var shot: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let src = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "IMG_2788", withExtension: "jpg", subdirectory: "Fixtures"))
        shot = "cache-\(UUID().uuidString).jpg"
        try Data(contentsOf: src).write(to: ShotImage.url(shot))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: ShotImage.url(shot))
        super.tearDown()
    }

    func testWarmThenPeekReturnsSameInstance() throws {
        XCTAssertNil(ShotImage.peek(shot, maxPixel: 300), "데우기 전인데 캐시에 있다")
        let first = try XCTUnwrap(ShotImage.warm(shot, maxPixel: 300))
        let peeked = try XCTUnwrap(ShotImage.peek(shot, maxPixel: 300), "데웠는데 캐시에 없다")
        XCTAssertTrue(first === peeked, "캐시를 지나치고 다시 디코드했다")
        XCTAssertTrue(first === ShotImage.warm(shot, maxPixel: 300), "warm 이 캐시를 안 쓴다")
    }

    func testDifferentSizesAreSeparateEntries() throws {
        let small = try XCTUnwrap(ShotImage.warm(shot, maxPixel: 200))
        let large = try XCTUnwrap(ShotImage.warm(shot, maxPixel: 600))
        XCTAssertFalse(small === large)
        XCTAssertLessThan(max(small.size.width, small.size.height), 210)
        XCTAssertGreaterThan(max(large.size.width, large.size.height), 210)
    }

    func testMissingFileIsHandled() {
        XCTAssertNil(ShotImage.warm("없는파일-\(UUID().uuidString).jpg", maxPixel: 300))
    }
}
