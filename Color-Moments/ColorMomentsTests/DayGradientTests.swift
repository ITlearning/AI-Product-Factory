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

    private func territory(_ stops: [DayGradient.Stop], of index: Int) -> Double {
        stops[index * 3 + 1].location - stops[index * 3].location
    }

    // 사진마다 [자리 시작, 자리 끝] + 사이 전환 가운데 한 점 — n장이면 3n-1개
    func testPebbleStopsGiveEachPhotoACoreAndOneMidpoint() {
        let stops = DayGradient.pebbleStops(for: [moment(0, "#E3B04B"), moment(10, "#6E9E5C"), moment(400, "#E07A5F")])
        XCTAssertEqual(stops.count, 8)
        XCTAssertEqual(stops.first?.location, 0)
        XCTAssertEqual(stops.last?.location ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(stops.map(\.location), stops.map(\.location).sorted())
        XCTAssertEqual([0, 1, 3, 4, 6, 7].map { stops[$0].hex },
                       ["#E3B04B", "#E3B04B", "#6E9E5C", "#6E9E5C", "#E07A5F", "#E07A5F"])
    }

    // 점심 짙은 회색 → 저녁 노을: 회색은 자리가 작고, 섞인 가운데 색은 회색 쪽에 붙는다
    func testNeutralPhotoGetsLessRoomThanVividOne() {
        let stops = DayGradient.pebbleStops(for: [moment(0, "#4A4A4E"), moment(400, "#E07A5F")])
        XCTAssertLessThan(territory(stops, of: 0), territory(stops, of: 1) * 0.5)
        let mid = stops[2].location
        XCTAssertLessThan(mid - stops[1].location, stops[3].location - mid)
    }

    // 6시간 공백도 10분 공백의 전환보다 2배 넘게 길어지지 않는다 — 공백이 돌을 덮지 않게
    func testLongGapOnlyStretchesTheTransitionALittle() {
        let stops = DayGradient.pebbleStops(for: [moment(0, "#E3B04B"), moment(10, "#6E9E5C"), moment(370, "#E07A5F")])
        let short = stops[3].location - stops[1].location
        let long = stops[6].location - stops[4].location
        XCTAssertGreaterThan(long, short)
        XCTAssertLessThan(long, short * 2)
    }

    func testPebbleStopsSingleMoment() {
        XCTAssertEqual(DayGradient.pebbleStops(for: [moment(0, "#AABBCC")]).map(\.location), [0])
        XCTAssertTrue(DayGradient.pebbleStops(for: []).isEmpty)
    }
}
