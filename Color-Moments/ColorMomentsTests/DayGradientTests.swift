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

    private func moment(_ minutesFromNoon: Int, _ hex: String, palette: [String]) -> Moment {
        var m = moment(minutesFromNoon, hex); m.palette = palette; return m
    }

    private var savedStamps = DayGradient.stamps
    private var savedGifted = DayGradient.isGifted

    override func setUp() {
        super.setUp()
        savedStamps = DayGradient.stamps
        savedGifted = DayGradient.isGifted
        DayGradient.stamps = PebbleStopsLog(defaults: UserDefaults(suiteName: "pebble-stops-\(UUID())")!)
        DayGradient.isGifted = { _ in false }
    }

    override func tearDown() {
        DayGradient.stamps = savedStamps
        DayGradient.isGifted = savedGifted
        super.tearDown()
    }

    private func assertLocations(_ a: [Double], _ b: [Double], accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.count, b.count, file: file, line: line)
        for (x, y) in zip(a, b) { XCTAssertEqual(x, y, accuracy: accuracy, file: file, line: line) }
    }

    func testOnePhotoDayGetsMainAndAccents() {
        let m = moment(0, "#E9B07D", palette: ["#E9B07D:70", "#4C6C81:20", "#CD906E:10"])
        let stops = DayGradient.pebbleStops(for: [m])
        XCTAssertEqual(stops.map(\.hex), ["#E9B07D", "#4C6C81", "#CD906E"], "1장 날도 곁들임 색이 들어간다")
        assertLocations(stops.map(\.location), [0.3, 0.7, 0.9], accuracy: 0.0001)
    }

    func testAccentsBelowEightPercentAreLeftOut() {
        let m = moment(0, "#E9B07D", palette: ["#E9B07D:90", "#4C6C81:6", "#CD906E:4"])
        XCTAssertEqual(DayGradient.pebbleStops(for: [m]).map(\.hex), ["#E9B07D"])
    }

    func testNoAccentFallsBackToSolid() {
        let m = moment(0, "#808085", palette: ["#808085:100"])
        let stops = DayGradient.pebbleStops(for: [m])
        XCTAssertEqual(stops.count, 1)
        XCTAssertEqual(stops.first?.location ?? -1, 0.5, accuracy: 0.0001)
    }

    func testTwoPhotosSplitTheBand() {
        let a = moment(0, "#AA0000", palette: ["#AA0000:70", "#00AA00:30"])
        let b = moment(60, "#0000AA", palette: ["#0000AA:100"])
        let stops = DayGradient.pebbleStops(for: [a, b])
        XCTAssertEqual(stops.map(\.hex), ["#AA0000", "#00AA00", "#0000AA"])
        assertLocations(stops.map(\.location), [0.15, 0.4, 0.75], accuracy: 0.0001)
    }

    func testMixedPaletteAndLegacyMoments() {
        let old = moment(0, "#111111")
        let new = moment(60, "#AA0000", palette: ["#AA0000:60", "#00AA00:40"])
        let stops = DayGradient.pebbleStops(for: [old, new])
        XCTAssertEqual(stops.map(\.hex), ["#111111", "#AA0000", "#00AA00"], "팔레트 없는 사진은 대표 색 100% 몫")
    }

    func testDayWithoutAnyPaletteKeepsLegacyRule() {
        let moments = [moment(0, "#111111"), moment(72, "#222222"), moment(480, "#444444")]
        XCTAssertEqual(DayGradient.pebbleStops(for: moments), DayGradient.legacyPebbleStops(for: moments),
                       "팔레트가 하나도 없는 날(옛 사진만)은 지금과 똑같이")
    }

    func testGiftedDayWithoutStampKeepsLegacyRule() {
        let m = moment(0, "#E9B07D", palette: ["#E9B07D:70", "#4C6C81:30"])
        DayGradient.isGifted = { $0 == m.dayKey }
        XCTAssertEqual(DayGradient.pebbleStops(for: [m]), DayGradient.legacyPebbleStops(for: [m]),
                       "1.1.x 에서 이미 받은 조약돌 — 업데이트 뒤에도 그림이 바뀌면 안 된다")
    }

    func testStampWinsOverEverything() {
        let m = moment(0, "#E9B07D", palette: ["#E9B07D:70", "#4C6C81:30"])
        let stamped = [DayGradient.Stop(location: 0, hex: "#123456")]
        DayGradient.stamps.stamp(m.dayKey, stamped)
        DayGradient.isGifted = { _ in true }
        XCTAssertEqual(DayGradient.pebbleStops(for: [m]), stamped)
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

    // 몇 분 사이로 찍은 사진도 조약돌에선 자리를 갖는다 — 시각만 쓰면 0.150·0.152 처럼 붙어 칼선이 된다.
    func testPebbleStopsBlendTimeAndOrder() {
        let moments = [moment(0, "#111111"), moment(72, "#222222"), moment(73, "#333333"), moment(480, "#444444")]
        let time = DayGradient.stops(for: moments).map(\.location)
        let pebble = DayGradient.pebbleStops(for: moments).map(\.location)
        for (i, (t, p)) in zip(time, pebble).enumerated() {
            XCTAssertEqual(p, 0.5 * t + 0.5 * Double(i) / 3, accuracy: 0.0001)
        }
        XCTAssertEqual(pebble.first, 0)
        XCTAssertEqual(pebble.last ?? 0, 1, accuracy: 0.0001)
        XCTAssertGreaterThan(pebble[2] - pebble[1], 0.15)
        XCTAssertEqual(DayGradient.pebbleStops(for: moments).map(\.hex), DayGradient.stops(for: moments).map(\.hex))
    }

    func testPebbleStopsSingleMoment() {
        XCTAssertEqual(DayGradient.pebbleStops(for: [moment(0, "#AABBCC")]).map(\.location), [0])
        XCTAssertTrue(DayGradient.pebbleStops(for: []).isEmpty)
    }
}
