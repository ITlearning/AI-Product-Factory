import XCTest
@testable import ColorMoments

final class TapCorrectionTests: XCTestCase {

    private let view = CGSize(width: 400, height: 400)
    private let portrait = CGSize(width: 200, height: 400)

    func testCenterMapsToCenter() throws {
        let p = try XCTUnwrap(TapCorrection.normalized(
            tap: CGPoint(x: 200, y: 200), in: view, imageSize: portrait))
        XCTAssertEqual(p.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(p.y, 0.5, accuracy: 0.001)
    }

    func testImageTopLeftIsNotViewTopLeft() throws {
        let p = try XCTUnwrap(TapCorrection.normalized(
            tap: CGPoint(x: 100, y: 0), in: view, imageSize: portrait))
        XCTAssertEqual(p.x, 0, accuracy: 0.001)
        XCTAssertEqual(p.y, 0, accuracy: 0.001)
    }

    func testTapOnLetterboxIsRejected() {
        XCTAssertNil(TapCorrection.normalized(tap: CGPoint(x: 20, y: 200),
                                              in: view, imageSize: portrait))
        XCTAssertNil(TapCorrection.normalized(tap: CGPoint(x: 380, y: 200),
                                              in: view, imageSize: portrait))
    }

    func testLandscapeLetterboxIsVertical() throws {
        let landscape = CGSize(width: 400, height: 200)
        XCTAssertNil(TapCorrection.normalized(tap: CGPoint(x: 200, y: 20),
                                              in: view, imageSize: landscape))
        let top = try XCTUnwrap(TapCorrection.normalized(
            tap: CGPoint(x: 200, y: 100), in: view, imageSize: landscape))
        XCTAssertEqual(top.y, 0, accuracy: 0.001)
        let center = try XCTUnwrap(TapCorrection.normalized(
            tap: CGPoint(x: 200, y: 200), in: view, imageSize: landscape))
        XCTAssertEqual(center.y, 0.5, accuracy: 0.001)
    }

    func testNoLetterboxWhenRatiosMatch() {
        for x in stride(from: 0.0, through: 400.0, by: 80) {
            XCTAssertNotNil(TapCorrection.normalized(tap: CGPoint(x: x, y: 200),
                                                     in: view, imageSize: view))
        }
    }

    func testRoundTripLandsBackOnTheSamePoint() throws {
        for tap in [CGPoint(x: 120, y: 40), CGPoint(x: 200, y: 200), CGPoint(x: 295, y: 380)] {
            let n = try XCTUnwrap(TapCorrection.normalized(tap: tap, in: view, imageSize: portrait))
            let back = try XCTUnwrap(TapCorrection.viewPoint(normalized: n, in: view, imageSize: portrait))
            XCTAssertEqual(back.x, tap.x, accuracy: 0.001)
            XCTAssertEqual(back.y, tap.y, accuracy: 0.001)
        }
    }

    func testZeroSizesAreRejected() {
        XCTAssertNil(TapCorrection.normalized(tap: .zero, in: .zero, imageSize: portrait))
        XCTAssertNil(TapCorrection.normalized(tap: .zero, in: view, imageSize: .zero))
        XCTAssertNil(TapCorrection.viewPoint(normalized: .zero, in: .zero, imageSize: portrait))
    }
}

final class RevertColorTests: XCTestCase {

    private var tempFile: URL!
    private var store: DayStore!
    private var shotName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("days-\(UUID().uuidString).json")
        store = DayStore(fileURL: tempFile)

        let src = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "IMG_5005", withExtension: "jpg", subdirectory: "Fixtures"),
            "픽스처 Fixtures/IMG_5005.jpg 없음")
        shotName = "revert-\(UUID().uuidString).jpg"
        try Data(contentsOf: src).write(to: ShotStore.directory.appendingPathComponent(shotName))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFile)
        try? FileManager.default.removeItem(at: ShotStore.directory.appendingPathComponent(shotName))
        super.tearDown()
    }

    private func seeded() -> Moment {
        let m = Moment(capturedAt: Date(), colorHex: "#FFC0CB",
                       fileName: shotName, source: .app, colorWasChosen: true)
        store.add(m)
        return m
    }

    func testRevertRestoresAutomaticColor() throws {
        let m = seeded()
        XCTAssertEqual(store.moments.first?.colorHex, "#FFC0CB")

        store.revertColor(m.id)

        let after = try XCTUnwrap(store.moments.first)
        XCTAssertFalse(after.colorWasChosen, "되돌렸는데 «직접 고름» 표시가 남아 있다")
        XCTAssertNotEqual(after.colorHex, "#FFC0CB", "색이 그대로다 — 다시 뽑지 않았다")
        XCTAssertEqual(after.id, m.id, "되돌리다가 순간이 다른 것으로 바뀌었다")
        XCTAssertEqual(after.fileName, m.fileName)
    }

    func testRevertIsRepeatable() throws {
        let m = seeded()
        store.revertColor(m.id)
        let first = try XCTUnwrap(store.moments.first?.colorHex)
        store.updateColor(m.id, to: "#00FF00")
        store.revertColor(m.id)
        XCTAssertEqual(store.moments.first?.colorHex, first, "같은 사진인데 자동값이 달라졌다")
    }

    func testRevertDoesNothingWhenPhotoIsGone() throws {
        let m = Moment(capturedAt: Date(), colorHex: "#FFC0CB",
                       fileName: "없는파일-\(UUID().uuidString).jpg", source: .app, colorWasChosen: true)
        store.add(m)
        store.revertColor(m.id)
        let after = try XCTUnwrap(store.moments.first)
        XCTAssertEqual(after.colorHex, "#FFC0CB", "사진이 없는데 색을 바꿨다")
        XCTAssertTrue(after.colorWasChosen)
    }
}
