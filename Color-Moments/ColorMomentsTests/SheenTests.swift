import SwiftUI
import XCTest
@testable import ColorMoments

@MainActor
final class SheenTests: XCTestCase {

    private let moments: [Moment] = {
        let base = Date()
        return ["#2B3550", "#33509B", "#6A4A7A", "#A6404A", "#B12E12"].enumerated().map {
            Moment(capturedAt: base.addingTimeInterval(Double($0.offset) * 30),
                   colorHex: $0.element, fileName: "t\($0.offset).jpg", source: .app)
        }
    }()

    private func luminance(sheen: Double) throws -> Double {
        let renderer = ImageRenderer(content:
            DayBadgeView(moments: moments, size: 150, showsCaption: false, sheen: sheen)
                .background(.black)
        )
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "렌더 실패 (sheen: \(sheen))")
        let cg = try XCTUnwrap(image.cgImage)

        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = try XCTUnwrap(CGContext(
            data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var sum = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            sum += (0.2126 * Double(pixels[i])
                  + 0.7152 * Double(pixels[i + 1])
                  + 0.0722 * Double(pixels[i + 2])) / 255
        }
        return sum / Double(w * h)
    }

    func testSheenIsVisibleMidSweep() throws {
        let rest = try luminance(sheen: 0)
        let mid = try luminance(sheen: 0.5)
        XCTAssertGreaterThan(mid, rest * 1.04,
            "슁이 한복판인데 밝기가 그대로다 — 띠가 조약돌 위를 지나지 않는다 (rest \(rest), mid \(mid))")
    }

    func testSheenLeavesNoTraceAtBothEnds() throws {
        let rest = try luminance(sheen: 0)
        let done = try luminance(sheen: 1)
        XCTAssertEqual(done, rest, accuracy: rest * 0.005,
            "진행도 1 에서 빛이 남아 있다 — 되돌리는 순간 뚝 끊긴다 (rest \(rest), done \(done))")
    }

    func testSheenDoesNotWashOutThePebble() throws {
        let rest = try luminance(sheen: 0)
        let mid = try luminance(sheen: 0.5)
        XCTAssertLessThan(mid, rest * 1.30,
            "슁이 조약돌을 통째로 덮는다 — 스침이 아니라 «뿌옇게 떴다 돌아오는» 그림이 된다 (rest \(rest), mid \(mid))")
    }

    func testDumpFramesWhenAsked() throws {
        guard let dir = ProcessInfo.processInfo.environment["SHEEN_DUMP"] else {
            throw XCTSkip("SHEEN_DUMP 미지정")
        }
        for step in stride(from: 0.0, through: 1.0, by: 0.125) {
            let renderer = ImageRenderer(content:
                DayBadgeView(moments: moments, size: 150, showsCaption: false, sheen: step)
                    .padding(24)
                    .background(.black)
            )
            renderer.scale = 3
            let png = try XCTUnwrap(renderer.uiImage?.pngData())
            let name = String(format: "sheen-%03d.png", Int(step * 1000))
            try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
        }
    }
}
