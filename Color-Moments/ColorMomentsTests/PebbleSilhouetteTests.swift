import XCTest
@testable import ColorMoments

final class PebbleSilhouetteTests: XCTestCase {

    /// 같은 날은 언제 어디서 돌려도 같은 조약돌이어야 한다.
    /// Swift 의 기본 Hasher 는 실행마다 시드가 달라서 못 쓴다 — 바이트를 직접 접는다.
    func testSameDayAlwaysGivesSameSilhouette() {
        let a = PebbleSilhouette(dayKey: "2026-09-22")
        let b = PebbleSilhouette(dayKey: "2026-09-22")
        XCTAssertEqual(a.widthRatio, b.widthRatio)
        XCTAssertEqual(a.topRounding, b.topRounding)
        XCTAssertEqual(a.bottomRounding, b.bottomRounding)
        XCTAssertEqual(a.tilt, b.tilt)
    }

    /// 모든 날이 같은 모양이면 수집물이 아니라 규격품이다.
    ///
    /// **폭은 이제 고정이다**(DESIGN §2.3 — 0.70). 세로로 쌓이는 홈에서 폭까지 흔들리면
    /// 줄이 들쭉날쭉해 보인다. 변주는 둥글기와 기울임이 담는다.
    func testDifferentDaysDifferInRoundingAndTilt() {
        let keys = (1...28).map { String(format: "2026-09-%02d", $0) }
        let shapes = keys.map { PebbleSilhouette(dayKey: $0) }
        let forms = Set(shapes.map { "\(($0.topRounding * 100).rounded())/\(($0.bottomRounding * 100).rounded())/\(($0.tilt * 10).rounded())" })
        XCTAssertGreaterThan(forms.count, 24, "28일 중 최소 25개는 모양이 달라야 한다")
        XCTAssertEqual(Set(shapes.map(\.widthRatio)).count, 1, "폭은 고정이어야 한다")
    }

    /// 범위를 벗어나면 조약돌이 아니라 막대나 공이 된다.
    func testStaysWithinPebbleProportions() {
        for d in 1...28 {
            let s = PebbleSilhouette(dayKey: String(format: "2026-09-%02d", d))
            XCTAssertEqual(s.widthRatio, 0.70, accuracy: 0.0001, "폭 비율은 0.70 고정")
            XCTAssertTrue((0.32...0.54).contains(s.topRounding))
            XCTAssertTrue((0.28...0.52).contains(s.bottomRounding))
            XCTAssertTrue((-7.0...7.0).contains(s.tilt))
        }
    }
}
