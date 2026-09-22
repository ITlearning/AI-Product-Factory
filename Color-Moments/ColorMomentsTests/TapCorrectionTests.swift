import XCTest
@testable import ColorMoments

/// 탭 좌표 → 사진 좌표 변환.
///
/// **조용히 틀리는 종류의 버그라 테스트로 잡는다.** `scaledToFit` 이 만든 레터박스를 무시하면
/// 누른 자리와 다른 색이 잡히는데, 화면상으로는 「색 추출이 이상하다」로만 보여서
/// 엉뚱한 곳(추출기)을 뜯게 된다.
final class TapCorrectionTests: XCTestCase {

    /// 세로로 긴 사진을 정사각 뷰에 넣으면 좌우에 빈 띠가 생긴다.
    /// 400x400 뷰 + 200x400 사진 → 그려지는 크기 200x400, 좌우 각각 100 의 띠.
    private let view = CGSize(width: 400, height: 400)
    private let portrait = CGSize(width: 200, height: 400)

    func testCenterMapsToCenter() throws {
        let p = try XCTUnwrap(TapCorrection.normalized(
            tap: CGPoint(x: 200, y: 200), in: view, imageSize: portrait))
        XCTAssertEqual(p.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(p.y, 0.5, accuracy: 0.001)
    }

    /// 사진의 왼쪽 위 모서리는 뷰의 (100, 0) 이다 — (0, 0) 이 아니다.
    func testImageTopLeftIsNotViewTopLeft() throws {
        let p = try XCTUnwrap(TapCorrection.normalized(
            tap: CGPoint(x: 100, y: 0), in: view, imageSize: portrait))
        XCTAssertEqual(p.x, 0, accuracy: 0.001)
        XCTAssertEqual(p.y, 0, accuracy: 0.001)
    }

    /// **레터박스를 누르면 nil.** 가장자리 색을 집어주면 사용자는 고른 적 없는 색을 갖게 된다.
    func testTapOnLetterboxIsRejected() {
        XCTAssertNil(TapCorrection.normalized(tap: CGPoint(x: 20, y: 200),
                                              in: view, imageSize: portrait))
        XCTAssertNil(TapCorrection.normalized(tap: CGPoint(x: 380, y: 200),
                                              in: view, imageSize: portrait))
    }

    /// 가로로 긴 사진이면 띠가 위아래에 생긴다.
    /// 400x400 뷰 + 400x200 사진 → 그려지는 크기 400x200, 위아래 각각 100 의 띠.
    /// 그러므로 **뷰의 y=100 은 사진의 위 모서리(0)이지 중앙이 아니다.**
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

    /// 뷰와 사진 비율이 같으면 띠가 없다 — 어디를 눌러도 사진 안이다.
    func testNoLetterboxWhenRatiosMatch() {
        for x in stride(from: 0.0, through: 400.0, by: 80) {
            XCTAssertNotNil(TapCorrection.normalized(tap: CGPoint(x: x, y: 200),
                                                     in: view, imageSize: view))
        }
    }

    /// **왕복이 어긋나면 표식이 누른 곳과 다른 데 찍힌다.**
    func testRoundTripLandsBackOnTheSamePoint() throws {
        for tap in [CGPoint(x: 120, y: 40), CGPoint(x: 200, y: 200), CGPoint(x: 295, y: 380)] {
            let n = try XCTUnwrap(TapCorrection.normalized(tap: tap, in: view, imageSize: portrait))
            let back = try XCTUnwrap(TapCorrection.viewPoint(normalized: n, in: view, imageSize: portrait))
            XCTAssertEqual(back.x, tap.x, accuracy: 0.001)
            XCTAssertEqual(back.y, tap.y, accuracy: 0.001)
        }
    }

    /// 크기가 0 이면(레이아웃 전) 계산하지 않는다 — 0 으로 나누면 NaN 이 좌표로 들어간다.
    func testZeroSizesAreRejected() {
        XCTAssertNil(TapCorrection.normalized(tap: .zero, in: .zero, imageSize: portrait))
        XCTAssertNil(TapCorrection.normalized(tap: .zero, in: view, imageSize: .zero))
        XCTAssertNil(TapCorrection.viewPoint(normalized: .zero, in: .zero, imageSize: portrait))
    }
}

/// 탭 보정을 무르는 길. **데이터를 건드리므로 UI 없이 못 박는다.**
final class RevertColorTests: XCTestCase {

    private var tempFile: URL!
    private var store: DayStore!
    private var shotName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("days-\(UUID().uuidString).json")
        store = DayStore(fileURL: tempFile)

        // 되돌리기는 «사진에서 다시 뽑는» 동작이라 진짜 사진이 있어야 한다.
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
        let m = Moment(capturedAt: Date(), colorHex: "#FFC0CB",   // 사용자가 고른 분홍
                       fileName: shotName, source: .app, colorWasChosen: true)
        store.add(m)
        return m
    }

    /// 되돌리면 자동값으로 돌아가고 «직접 고름» 표시가 지워진다.
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

    /// **추출기가 결정론적이라 자동값을 따로 보관하지 않는다** — 그 전제가 깨지면 되돌리기가 거짓말이 된다.
    func testRevertIsRepeatable() throws {
        let m = seeded()
        store.revertColor(m.id)
        let first = try XCTUnwrap(store.moments.first?.colorHex)
        store.updateColor(m.id, to: "#00FF00")
        store.revertColor(m.id)
        XCTAssertEqual(store.moments.first?.colorHex, first, "같은 사진인데 자동값이 달라졌다")
    }

    /// 사진이 사라졌으면 아무것도 하지 않는다. 지어낸 색으로 덮어쓰면 기록이 조용히 망가진다.
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
