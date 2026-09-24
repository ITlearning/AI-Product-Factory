import XCTest
@testable import ColorMoments

final class DayTimelineTests: XCTestCase {

    private func moment(_ minutes: Int, _ hex: String = "#808080") -> Moment {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 22; c.hour = 9
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        return Moment(capturedAt: cal.date(from: c)!.addingTimeInterval(Double(minutes) * 60),
                      colorHex: hex, fileName: "\(minutes).jpg", source: .app)
    }

    func testTicksSitWhereTheGradientStops() {
        let ms = [moment(0), moment(30), moment(600), moment(620)]
        let ys = DayTimeline.place(ms, height: 360, photoHeight: 127).map(\.y)
        let stops = DayGradient.stops(for: ms).map { CGFloat($0.location) * 360 }
        XCTAssertEqual(ys, stops, "두 벌로 나뉘면 띠의 색과 눈금이 어긋난다")
    }

    func testEveningBurstBunchesAtTheBottom() {
        let ys = DayTimeline.place([moment(0), moment(600), moment(610), moment(620)],
                                   height: 360, photoHeight: 127).map(\.y)
        XCTAssertGreaterThan(ys[1], 340, "균등 분할이면 120 — 몰아 찍은 저녁이 지워진다")
    }

    func testOverlappingPhotosStepRightAndResetWhenClear() {
        let p = DayTimeline.place([moment(0), moment(10), moment(20), moment(600)],
                                  height: 360, photoHeight: 127)
        XCTAssertEqual(p.map(\.shift), [0, 1, 2, 0])
    }

    func testShiftWrapsInsteadOfRunningOffScreen() {
        let ms = (0..<6).map { moment($0) } + [moment(600)]
        let shifts = DayTimeline.place(ms, height: 360, photoHeight: 127, maxShift: 3).map(\.shift)
        XCTAssertEqual(Array(shifts.prefix(6)), [0, 1, 2, 3, 0, 1])
    }

    func testCrowdedTimeLabelsAreThinned() {
        let p = DayTimeline.place([moment(0), moment(1), moment(300), moment(600)],
                                  height: 360, photoHeight: 127)
        XCTAssertEqual(p.map(\.showsTime), [true, false, true, true])
    }

    func testSingleMomentSitsAtTheTop() {
        let p = DayTimeline.place([moment(0)], height: 360, photoHeight: 127)
        XCTAssertEqual(p.first?.y, 0)
        XCTAssertEqual(p.first?.showsTime, true)
    }

    func testAxisHeightIsZeroForOneOrNoPhotos() {
        XCTAssertEqual(DayTimeline.axisHeight(count: 0, photoHeight: 127), 0)
        XCTAssertEqual(DayTimeline.axisHeight(count: 1, photoHeight: 127), 0)
    }

    func testAxisHeightScalesWithPhotoCount() {
        XCTAssertEqual(DayTimeline.axisHeight(count: 2, photoHeight: 127), 190.5)
    }

    func testAxisHeightCapsAtMaxHeight() {
        XCTAssertEqual(DayTimeline.axisHeight(count: 10, photoHeight: 127), 360)
    }
}
