import SwiftUI
import XCTest
@testable import ColorMoments

/// 슁(표면을 훑는 빛)이 **실제로 보이는가**.
///
/// 이 테스트가 있는 이유: 같은 자리가 두 번 터졌다.
/// 1) 띠를 `Double?` 로 두고 `if let` 으로 껐다 켰더니 `nil → 1` 이 값 변화가 아니라 뷰 삽입이 돼
///    애니메이션이 통째로 날아갔다. 띠가 도착지에 멈춰 선 채 조약돌을 옅게 덮고만 있었다.
/// 2) 띠를 너무 넓게 잡았더니 지나가는 내내 조약돌을 통째로 덮어, 스침이 아니라
///    «전체가 뿌옇게 떴다가 돌아오는» 그림이 됐다.
///
/// 그래서 «중간엔 밝고, 양 끝은 안 그린 것과 같다»를 픽셀로 못 박는다.
@MainActor
final class SheenTests: XCTestCase {

    private let moments: [Moment] = {
        let base = Date()
        return ["#2B3550", "#33509B", "#6A4A7A", "#A6404A", "#B12E12"].enumerated().map {
            Moment(capturedAt: base.addingTimeInterval(Double($0.offset) * 30),
                   colorHex: $0.element, fileName: "t\($0.offset).jpg", source: .app)
        }
    }()

    /// 조약돌 한 장을 그려 평균 밝기를 낸다.
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

    /// 한복판에서는 확실히 밝아야 한다. 안 밝으면 슁이 «안 보이는» 것이다.
    func testSheenIsVisibleMidSweep() throws {
        let rest = try luminance(sheen: 0)
        let mid = try luminance(sheen: 0.5)
        XCTAssertGreaterThan(mid, rest * 1.04,
            "슁이 한복판인데 밝기가 그대로다 — 띠가 조약돌 위를 지나지 않는다 (rest \(rest), mid \(mid))")
    }

    /// 양 끝은 «안 그린 것»과 같아야 한다. 그래야 들고 날 때 뚝 끊기지 않는다.
    func testSheenLeavesNoTraceAtBothEnds() throws {
        let rest = try luminance(sheen: 0)
        let done = try luminance(sheen: 1)
        XCTAssertEqual(done, rest, accuracy: rest * 0.005,
            "진행도 1 에서 빛이 남아 있다 — 되돌리는 순간 뚝 끊긴다 (rest \(rest), done \(done))")
    }

    /// 스침이지 덮개가 아니다. 한복판이라도 조약돌을 하얗게 덮으면 안 된다.
    func testSheenDoesNotWashOutThePebble() throws {
        let rest = try luminance(sheen: 0)
        let mid = try luminance(sheen: 0.5)
        XCTAssertLessThan(mid, rest * 1.30,
            "슁이 조약돌을 통째로 덮는다 — 스침이 아니라 «뿌옇게 떴다 돌아오는» 그림이 된다 (rest \(rest), mid \(mid))")
    }

    /// 눈으로도 본다. `SHEEN_DUMP=<디렉토리>` 를 주면 진행도별 프레임을 PNG 로 떨군다.
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
