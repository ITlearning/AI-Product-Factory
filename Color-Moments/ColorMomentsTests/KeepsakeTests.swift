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

    func testShareTextParticleFollowsFinalConsonant() throws {
        let url = try XCTUnwrap(URL(string: "https://apps.apple.com/app/id0"))
        XCTAssertTrue(try XCTUnwrap(Keepsake.shareText(pebbleName: "노을", appStoreURL: url)).hasPrefix("노을을 건네요"))
        XCTAssertTrue(try XCTUnwrap(Keepsake.shareText(pebbleName: "바다", appStoreURL: url)).hasPrefix("바다를 건네요"))
        XCTAssertTrue(try XCTUnwrap(Keepsake.shareText(pebbleName: "9월의 한 줌", appStoreURL: url))
            .hasPrefix("9월의 한 줌을 건네요"))
        XCTAssertTrue(try XCTUnwrap(Keepsake.shareText(pebbleName: "몽돌", appStoreURL: url)).hasPrefix("몽돌을 건네요"))
    }

    func testObjectParticle() {
        XCTAssertEqual(Keepsake.objectParticle(after: "노을"), "을")
        XCTAssertEqual(Keepsake.objectParticle(after: "바다"), "를")
        XCTAssertEqual(Keepsake.objectParticle(after: "abc"), "을")
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

    private func image<V: View>(_ view: V) throws -> UIImage {
        let r = ImageRenderer(content: view.frame(width: CardExporter.pointSize.width,
                                                  height: CardExporter.pointSize.height))
        r.scale = 3
        return try XCTUnwrap(r.uiImage)
    }

    func testRenderWithNoMomentsIsNil() {
        // 돌이 없는 카드는 건넬 게 없다 — nil 이면 시트가 「카드를 만들 수 없어요」로 빠진다.
        XCTAssertNil(CardExporter.render(dayKey: "2026-09-23", pebbleMoments: []))
    }

    func testHandfulWithPebblesIsNotBlankAndEmptyHandfulIsNil() {
        XCTAssertNotNil(CardExporter.renderHandful(month: "2026-08", pebbleGroups: [moments]))
        XCTAssertNil(CardExporter.renderHandful(month: "2026-08", pebbleGroups: []))
    }

    func testBackgroundWithoutPebbleIsBlank() throws {
        // 조약돌 질감만 비고 배경 그라데이션은 그려진 경우 — 불투명 배경이라 알파만 봐서는 못 잡던 것.
        let bgOnly = try image(ZStack {
            Tone.base
            DayGradientView(moments: moments, axis: .vertical).blur(radius: 90).opacity(0.55)
        })
        XCTAssertTrue(CardExporter.isBlank(bgOnly))
        XCTAssertTrue(CardExporter.isBlank(try image(Tone.base)))
    }

    func testCardWithPebbleIsNotBlank() throws {
        XCTAssertFalse(CardExporter.isBlank(try image(PebbleCard(dayKey: "2026-09-23", pebbleMoments: moments))))
    }
}
