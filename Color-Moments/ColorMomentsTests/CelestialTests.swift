import XCTest
@testable import ColorMoments

/// 기준값은 docs/designs/tools/sun-altitude-check.mjs(다른 공식)로 낸 서울 해 높이.
final class CelestialTests: XCTestCase {

    private func seoul(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        c.timeZone = TimeZone(identifier: "Asia/Seoul")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func testSunAltitudeMatchesTheReferenceTool() {
        for (date, expected) in [(seoul(2026, 7, 15, 17, 30), 26.14), (seoul(2026, 12, 15, 6, 30), -13.36),
                                 (seoul(2026, 6, 15, 6, 30), 13.44), (seoul(2026, 6, 21, 12, 30), 75.85),
                                 (seoul(2026, 9, 26, 19, 16), -11.0)] {
            XCTAssertEqual(Celestial.sunAltitude(at: date, latitude: Celestial.seoul.latitude, longitude: Celestial.seoul.longitude),
                           expected, accuracy: 0.6, "\(date)")
        }
    }

    func testMoonAgeAtKnownPhases() {
        var c = DateComponents(); c.year = 2024; c.month = 10; c.day = 2; c.hour = 18; c.minute = 49
        c.timeZone = TimeZone(identifier: "UTC")
        let newMoon = Calendar(identifier: .gregorian).date(from: c)!
        let age = Celestial.moonAge(at: newMoon)
        XCTAssertTrue(age < 1 || age > Celestial.synodicMonth - 1, "2024-10-02 삭: \(age)")
        XCTAssertEqual(Celestial.moonAge(at: newMoon.addingTimeInterval(14.77 * 86_400)), 14.77, accuracy: 1)
    }
}
