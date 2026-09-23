import XCTest
@testable import ColorMoments

final class PebbleSilhouetteTests: XCTestCase {

    func testSameDayAlwaysGivesSameSilhouette() {
        let a = PebbleSilhouette(dayKey: "2026-09-22")
        let b = PebbleSilhouette(dayKey: "2026-09-22")
        XCTAssertEqual(a.widthRatio, b.widthRatio)
        XCTAssertEqual(a.topRounding, b.topRounding)
        XCTAssertEqual(a.bottomRounding, b.bottomRounding)
        XCTAssertEqual(a.tilt, b.tilt)
    }

    func testDifferentDaysDifferInRoundingAndTilt() {
        let keys = (1...28).map { String(format: "2026-09-%02d", $0) }
        let shapes = keys.map { PebbleSilhouette(dayKey: $0) }
        let forms = Set(shapes.map { "\(($0.topRounding * 100).rounded())/\(($0.bottomRounding * 100).rounded())/\(($0.tilt * 10).rounded())" })
        XCTAssertGreaterThan(forms.count, 24, "28일 중 최소 25개는 모양이 달라야 한다")
        XCTAssertEqual(Set(shapes.map(\.widthRatio)).count, 1, "폭은 고정이어야 한다")
    }

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
