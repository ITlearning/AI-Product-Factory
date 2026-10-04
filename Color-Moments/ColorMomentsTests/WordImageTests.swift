import CoreGraphics
import XCTest
@testable import ColorMoments

final class WordImageTests: XCTestCase {
    private func image(_ w: Int, _ h: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    func testLandscapeIsCenterCroppedToSquare() throws {
        let out = try XCTUnwrap(WordImage.input(from: image(800, 600)))
        XCTAssertEqual([out.width, out.height], [224, 224])
    }

    func testPortraitToo() throws {
        let out = try XCTUnwrap(WordImage.input(from: image(600, 900)))
        XCTAssertEqual([out.width, out.height], [224, 224])
    }
}
