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
    func testDifferentDaysDiffer() {
        let keys = (1...28).map { String(format: "2026-09-%02d", $0) }
        let shapes = keys.map { PebbleSilhouette(dayKey: $0) }
        let widths = Set(shapes.map { ($0.widthRatio * 1000).rounded() })
        XCTAssertGreaterThan(widths.count, 20, "28일 중 최소 20개는 폭이 달라야 한다")
    }

    /// 범위를 벗어나면 조약돌이 아니라 막대나 공이 된다.
    func testStaysWithinPebbleProportions() {
        for d in 1...28 {
            let s = PebbleSilhouette(dayKey: String(format: "2026-09-%02d", d))
            XCTAssertTrue((0.58...0.76).contains(s.widthRatio), "폭 비율 이탈: \(s.widthRatio)")
            XCTAssertTrue((0.38...0.52).contains(s.topRounding))
            XCTAssertTrue((0.34...0.50).contains(s.bottomRounding))
            XCTAssertTrue((-4.0...4.0).contains(s.tilt))
        }
    }
}
