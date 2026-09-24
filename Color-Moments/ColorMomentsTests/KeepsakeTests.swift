import SwiftUI
import XCTest
@testable import ColorMoments

final class KeepsakeTests: XCTestCase {

    func testUngiftedDayCannotMakeCard() {
        XCTAssertFalse(Keepsake.canMakeCard(dayKey: "2026-09-23", isGifted: { _ in false }))
    }

    func testGiftedDayCanMakeCard() {
        XCTAssertTrue(Keepsake.canMakeCard(dayKey: "2026-09-23", isGifted: { $0 == "2026-09-23" }))
    }

    func testShareTextIsNilWithoutURL() {
        XCTAssertNil(Keepsake.shareText(pebbleName: "노을", appStoreURL: nil))
    }

    func testShareTextIncludesNameAndURLWhenSet() throws {
        let url = try XCTUnwrap(URL(string: "https://apps.apple.com/app/id0"))
        let text = try XCTUnwrap(Keepsake.shareText(pebbleName: "노을", appStoreURL: url))
        XCTAssertTrue(text.contains("노을"))
        XCTAssertTrue(text.contains(url.absoluteString))
    }
}

@MainActor
final class CardExporterTests: XCTestCase {

    private let moments: [Moment] = {
        let base = Date().addingTimeInterval(-86_400)
        return ["#2B3550", "#33509B", "#6A4A7A", "#A6404A", "#B12E12"].enumerated().map {
            Moment(capturedAt: base.addingTimeInterval(Double($0.offset) * 1800),
                   colorHex: $0.element, fileName: "kc\($0.offset).jpg", source: .app)
        }
    }()

    func testRenderProducesFullSizeNonBlankImage() throws {
        let image = try XCTUnwrap(CardExporter.render(dayKey: "2026-09-23", pebbleMoments: moments),
                                  "카드 렌더 실패 — PebbleView 질감이 ImageRenderer 에서 비었을 수 있다")
        XCTAssertEqual(image.size, CardExporter.pointSize)
        XCTAssertFalse(CardExporter.isBlank(image))
    }

    func testRenderWithNoMomentsIsStillNotBlank() {
        // 배경(Tone.base)만 있어도 완전 투명은 아니다 — nil 로 빠지면 공유 버튼이 통째로 숨는다.
        let image = CardExporter.render(dayKey: "2026-09-23", pebbleMoments: [])
        XCTAssertNotNil(image)
    }
}
