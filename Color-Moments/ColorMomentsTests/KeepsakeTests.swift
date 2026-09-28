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

    func testInitialPhotoIsTheOneBeingViewed() {
        let photos = (0..<3).map { Moment(capturedAt: Date(timeIntervalSince1970: Double($0) * 60),
                                          colorHex: "#2B3550", fileName: "p\($0).jpg", source: .app) }
        XCTAssertEqual(Keepsake.initialPhotoID(photos: photos, viewing: photos[2].id), photos[2].id)
    }

    func testInitialPhotoFallsBackToFirst() {
        let photos = (0..<3).map { Moment(capturedAt: Date(timeIntervalSince1970: Double($0) * 60),
                                          colorHex: "#2B3550", fileName: "p\($0).jpg", source: .app) }
        XCTAssertEqual(Keepsake.initialPhotoID(photos: photos, viewing: nil), photos[0].id)
        // 다른 날 사진을 보고 있었다면 그날 첫 사진으로.
        XCTAssertEqual(Keepsake.initialPhotoID(photos: photos, viewing: UUID()), photos[0].id)
        XCTAssertNil(Keepsake.initialPhotoID(photos: [], viewing: nil))
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
        XCTAssertEqual(image.cgImage?.width, 1080)
        XCTAssertEqual(image.cgImage?.height, 1920)
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

    func testFaceCardWithoutPhotoPassesBlankCheck() throws {
        // 받은 기록처럼 사진이 없으면 그 순간의 색 면 + 조약돌 — 빈 카드로 막히면 안 된다.
        let card = try XCTUnwrap(CardExporter.render(dayKey: "2026-09-23", pebbleMoments: moments,
                                                     face: moments[3], photo: nil))
        XCTAssertEqual(card.cgImage?.width, 1080)
        XCTAssertEqual(card.cgImage?.height, 1920)
    }

    func testCardWithoutPebbleIsBlank() throws {
        for photo in [nil, Self.photo(width: 1200, height: 900), Self.photo(width: 900, height: 1600)] {
            let region = CardExporter.blankRegion(photo: photo)
            let with = try image(PebbleCard(dayKey: "2026-09-23", pebbleMoments: moments, face: moments[1],
                                            photo: photo, drawsPebble: true))
            let without = try image(PebbleCard(dayKey: "2026-09-23", pebbleMoments: moments, face: moments[1],
                                               photo: photo, drawsPebble: false))
            XCTAssertFalse(CardExporter.isBlank(with, region: region), "돌 있는 카드가 빈 카드로 걸렸다 \(String(describing: photo?.size))")
            XCTAssertTrue(CardExporter.isBlank(without, region: region), "돌 빠진 카드를 못 잡았다 \(String(describing: photo?.size))")
        }
    }

    func testPhotoCardFromAssetSourceRendersNonBlank() async throws {
        let source = FakeAssetSource(image: Self.photo(width: 1600, height: 1200))
        let saved = ShotImage.assetSource
        ShotImage.assetSource = source
        defer { ShotImage.assetSource = saved }

        var m = moments[2]
        m.assetID = "fake-asset"
        let fetched = await CardExporter.cardPhoto(m)
        let photo = try XCTUnwrap(fetched)
        XCTAssertEqual(source.requested, [CardExporter.photoPixels])
        let card = try XCTUnwrap(CardExporter.render(dayKey: "2026-09-23", pebbleMoments: moments, face: m, photo: photo),
                                 "사진 카드가 빈 카드로 걸렸다")
        XCTAssertEqual(card.cgImage?.width, 1080)
        XCTAssertEqual(card.cgImage?.height, 1920)
        XCTAssertGreaterThan(try XCTUnwrap(CardExporter.regionStats(card, region: CardExporter.blankRegion(photo: photo)))
            .lumaVariance, 50)
    }

    func testPhotoKeepsItsAspectInsideTheCard() {
        let wide = PebbleCardLayout.photoFrame(aspect: 4 / 3)
        let tall = PebbleCardLayout.photoFrame(aspect: 9 / 16)
        XCTAssertEqual(wide.width / wide.height, 4 / 3, accuracy: 0.001)
        XCTAssertEqual(tall.width / tall.height, 9 / 16, accuracy: 0.001)
        XCTAssertGreaterThan(tall.height, wide.height, "세로 사진이 크게 들어가지 않는다")
        XCTAssertGreaterThanOrEqual(wide.width, tall.width)
    }

    /// 줄무늬 사진 — 한 색이면 사진 자체가 빈 판정과 구분이 안 된다.
    static func photo(width: Int, height: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            for i in 0..<12 {
                UIColor(hue: CGFloat(i) / 12, saturation: 0.6, brightness: 0.8, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: CGFloat(i * height / 12), width: CGFloat(width), height: CGFloat(height / 12 + 1)))
            }
        }
    }
}

private final class FakeAssetSource: AssetImageSource, @unchecked Sendable {
    let image: UIImage
    private(set) var requested: [CGFloat] = []

    init(image: UIImage) { self.image = image }

    func image(assetID: String, maxPixel: CGFloat) async -> UIImage? {
        requested.append(maxPixel)
        return image
    }
}
