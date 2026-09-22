import SwiftUI
import XCTest
@testable import ColorMoments

/// 조약돌을 실제로 그려서 확인하는 자리. `DESIGN.md` §2.4 여섯 겹.
///
/// 표면은 **눈으로만 판정되는 것**이라 단언을 걸지 않는다. 대신 `PEBBLE_DUMP=<디렉토리>` 를 주면
/// 날짜별·크기별 PNG 를 떨군다. 디자인을 만질 때마다 다시 굽는다.
@MainActor
final class PebbleRenderTests: XCTestCase {

    private func day(_ hexes: [String], daysAgo: Int) -> [Moment] {
        let base = Date().addingTimeInterval(Double(-86_400 * daysAgo))
        return hexes.enumerated().map {
            Moment(capturedAt: base.addingTimeInterval(Double($0.offset) * 1800),
                   colorHex: $0.element, fileName: "p\(daysAgo)-\($0.offset).jpg", source: .app)
        }
    }

    /// 그레인 텍스처는 **한 번만 구워야 한다.** 조약돌마다 만들면 스크롤에서 죽는다.
    func testGrainIsBakedOnceAndTiny() throws {
        let a = try XCTUnwrap(Grain.image, "그레인 텍스처 생성 실패 — 4번 겹이 통째로 빠진다")
        let b = try XCTUnwrap(Grain.image)
        XCTAssertTrue(a === b, "그레인이 매번 새로 만들어진다 — static let 캐시가 깨졌다")
        XCTAssertEqual(a.size, CGSize(width: Grain.tileSide, height: Grain.tileSide))
    }

    func testDumpPebblesWhenAsked() throws {
        guard let dir = ProcessInfo.processInfo.environment["PEBBLE_DUMP"] else {
            throw XCTSkip("PEBBLE_DUMP 미지정")
        }
        let cases: [(String, [Moment])] = [
            ("노을",   day(["#2B3550", "#33509B", "#6A4A7A", "#A6404A", "#B12E12"], daysAgo: 1)),
            ("하늘빛", day(["#7FB0DC", "#8CB8DE", "#6795BC", "#3C6A9B"], daysAgo: 2)),
            ("풀빛",   day(["#5B7F5B", "#8FA36B", "#A79C87"], daysAgo: 3)),
            ("잿빛",   day(["#6B6261", "#887F7E", "#9D917C"], daysAgo: 4)),
            ("단색",   day(["#B12E12"], daysAgo: 5)),
        ]
        for (name, moments) in cases {
            for h in [84.0, 130.0, 180.0] as [CGFloat] {
                let r = ImageRenderer(content:
                    PebbleView(moments: moments, height: h)
                        .padding(26)
                        .background(Tone.base))
                r.scale = 3
                let png = try XCTUnwrap(r.uiImage?.pngData())
                try png.write(to: URL(fileURLWithPath: dir)
                    .appendingPathComponent("pebble-\(name)-\(Int(h)).png"))
            }
        }
        // 슁이 지나가는 중간도 한 장
        let r = ImageRenderer(content:
            PebbleView(moments: cases[0].1, height: 180, sheen: 0.5)
                .padding(26).background(Tone.base))
        r.scale = 3
        try XCTUnwrap(r.uiImage?.pngData())
            .write(to: URL(fileURLWithPath: dir).appendingPathComponent("pebble-sheen.png"))
    }
}
