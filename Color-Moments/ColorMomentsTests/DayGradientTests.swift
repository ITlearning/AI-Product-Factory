import XCTest
@testable import ColorMoments

final class DayGradientTests: XCTestCase {

    private func moment(_ minutesFromNoon: Int, _ hex: String) -> Moment {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 22; c.hour = 12
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let base = cal.date(from: c)!
        return Moment(capturedAt: base.addingTimeInterval(Double(minutesFromNoon) * 60),
                      colorHex: hex, fileName: "\(minutesFromNoon).jpg", source: .app)
    }

    func testEmptyDayHasNoStops() {
        XCTAssertTrue(DayGradient.stops(for: []).isEmpty)
    }

    func testSingleMomentIsOneSolidStop() {
        let stops = DayGradient.stops(for: [moment(0, "#AABBCC")])
        XCTAssertEqual(stops.count, 1)
        XCTAssertEqual(stops.first?.hex, "#AABBCC")
    }

    func testStopsSpanZeroToOne() throws {
        let stops = DayGradient.stops(for: [moment(0, "#111111"), moment(120, "#222222")])
        XCTAssertEqual(try XCTUnwrap(stops.first).location, 0, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(stops.last).location, 1, accuracy: 0.0001)
    }

    func testIntervalsArePreservedNotEqualised() {

        let stops = DayGradient.stops(for: [
            moment(0, "#111111"), moment(10, "#222222"), moment(100, "#333333"),
        ])
        XCTAssertEqual(stops.count, 3)
        XCTAssertEqual(stops[1].location, 0.1, accuracy: 0.001,
                       "균등 분할이면 0.5 가 나온다 — 그러면 몰아 찍은 하루가 지워진다")
    }

    func testStopsFollowCaptureOrderRegardlessOfInput() {
        let stops = DayGradient.stops(for: [moment(60, "#LATE00"), moment(0, "#EAR000")])
        XCTAssertEqual(stops.first?.hex, "#EAR000")
        XCTAssertEqual(stops.last?.hex, "#LATE00")
    }

    func testSimultaneousMomentsDoNotDivideByZero() {
        let stops = DayGradient.stops(for: [moment(0, "#111111"), moment(0, "#222222"), moment(0, "#333333")])
        XCTAssertEqual(stops.count, 3)
        XCTAssertEqual(stops[1].location, 0.5, accuracy: 0.0001)
        XCTAssertTrue(stops.allSatisfy { $0.location.isFinite })
    }

    func testSpanReportsFirstAndLastCapture() {
        let span = DayGradient.span(for: [moment(30, "#111111"), moment(0, "#222222")])
        XCTAssertEqual(span?.from, moment(0, "#222222").capturedAt)
        XCTAssertEqual(span?.to, moment(30, "#111111").capturedAt)
    }
}
