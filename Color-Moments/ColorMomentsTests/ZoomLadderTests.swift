import XCTest
@testable import ColorMoments

final class ZoomLadderTests: XCTestCase {

    // 가상 장치의 videoZoomFactor 1 은 가장 넓은 렌즈다. 초광각이 있으면 배수 0.5 로 광각을 1× 에 맞춘다.
    private func triple(tele switchOver: Double) -> ZoomLadder {
        ZoomLadder(multiplier: 0.5, switchOvers: [2, switchOver], minRaw: 1, maxRaw: 190)
    }

    // MARK: 기기별 버튼

    func testPresetsFollowRealLenses() {
        XCTAssertEqual(triple(tele: 10).presets, [0.5, 1, 2, 5], "16 Pro · 15 Pro Max — 5배 망원")
        XCTAssertEqual(triple(tele: 6).presets, [0.5, 1, 2, 3], "13 Pro · 14 Pro · 15 Pro — 3배 망원")
        XCTAssertEqual(ZoomLadder(multiplier: 0.5, switchOvers: [2], minRaw: 1, maxRaw: 123).presets, [0.5, 1, 2],
                       "13 · 16 — 초광각 + 광각")
        XCTAssertEqual(ZoomLadder(multiplier: 1, switchOvers: [2], minRaw: 1, maxRaw: 16).presets, [1, 2],
                       "XS — 광각 + 2배 망원")
        XCTAssertEqual(ZoomLadder(multiplier: 1, switchOvers: [], minRaw: 1, maxRaw: 16).presets, [1, 2],
                       "SE · 16e — 광각 하나")
    }

    func testCropIsLeftOutWhenATeleSitsNearTwo() {
        XCTAssertEqual(triple(tele: 4).presets, [0.5, 1, 2], "11 Pro · 12 Pro — 2배 망원이 곧 2배")
        XCTAssertEqual(triple(tele: 5).presets, [0.5, 1, 2.5], "12 Pro Max — 2.5배 망원 옆에 2배를 두지 않는다")
    }

    func testNoButtonBeyondWhatTheDeviceReaches() {
        let ladder = ZoomLadder(multiplier: 1, switchOvers: [], minRaw: 1, maxRaw: 1.5)
        XCTAssertEqual(ladder.presets, [1])
        XCTAssertEqual(ladder.range, 1...1.5)
    }

    func testSwitchOverNoiseRoundsToTheLens() {
        let ladder = ZoomLadder(multiplier: 0.5, switchOvers: [1.9999, 10.0001], minRaw: 1, maxRaw: 190)
        XCTAssertEqual(ladder.presets, [0.5, 1, 2, 5])
    }

    // MARK: 범위

    func testRangeStopsAtTwiceTheLongestButton() {
        XCTAssertEqual(triple(tele: 10).range, 0.5...10)
        XCTAssertEqual(triple(tele: 6).range, 0.5...6)
        XCTAssertEqual(ZoomLadder(multiplier: 0.5, switchOvers: [2], minRaw: 1, maxRaw: 123).range, 0.5...4)
        XCTAssertEqual(ZoomLadder(multiplier: 1, switchOvers: [], minRaw: 1, maxRaw: 5).range, 1...4)
        XCTAssertEqual(ZoomLadder(multiplier: 0.5, switchOvers: [2, 10], minRaw: 1, maxRaw: 12).range, 0.5...6,
                       "장치 상한이 더 낮으면 장치를 따른다")
    }

    func testClampKeepsPinchInsideTheRange() {
        let ladder = triple(tele: 10)
        XCTAssertEqual(ladder.clamped(0.2), 0.5)
        XCTAssertEqual(ladder.clamped(3.7), 3.7)
        XCTAssertEqual(ladder.clamped(40), 10)
    }

    // MARK: 환산

    func testRawAndDisplayConvertThroughTheMultiplier() {
        let ladder = triple(tele: 10)
        XCTAssertEqual(ladder.raw(forDisplay: 0.5), 1)
        XCTAssertEqual(ladder.raw(forDisplay: 1), 2)
        XCTAssertEqual(ladder.raw(forDisplay: 5), 10)
        XCTAssertEqual(ladder.raw(forDisplay: 40), 20, "범위 밖은 끝에서 멈춘다")
        XCTAssertEqual(ladder.display(forRaw: 2.8), 1.4, accuracy: 1e-9)

        let wide = ZoomLadder(multiplier: 1, switchOvers: [], minRaw: 1, maxRaw: 16)
        XCTAssertEqual(wide.raw(forDisplay: 2), 2)
    }

    func testZeroMultiplierFallsBackToOne() {
        let ladder = ZoomLadder(multiplier: 0, switchOvers: [], minRaw: 1, maxRaw: 16)
        XCTAssertEqual(ladder.presets, [1, 2])
        XCTAssertEqual(ladder.raw(forDisplay: 2), 2)
    }

    // MARK: 표시

    func testLabelShowsOneDecimalAndDropsTrailingZero() {
        XCTAssertEqual(ZoomLadder.label(1.43), "1.4×")
        XCTAssertEqual(ZoomLadder.label(2), "2×")
        XCTAssertEqual(ZoomLadder.label(1.97), "2×", "반올림해 정수가 되면 소수점을 뗀다")
        XCTAssertEqual(ZoomLadder.label(0.5), "0.5×")
        XCTAssertEqual(ZoomLadder.label(0.72), "0.7×")
        XCTAssertEqual(ZoomLadder.label(9.96), "10×")
        XCTAssertEqual(ZoomLadder.label(10.4), "10×", "10배부터는 정수만")
    }

    func testPresetLabelIsShort() {
        XCTAssertEqual(ZoomLadder.presetLabel(0.5), ".5")
        XCTAssertEqual(ZoomLadder.presetLabel(1), "1")
        XCTAssertEqual(ZoomLadder.presetLabel(2.5), "2.5")
        XCTAssertEqual(ZoomLadder.presetLabel(5), "5")
    }

    // MARK: 가장 가까운 버튼

    func testNearestButtonIsMeasuredInRatios() {
        let ladder = triple(tele: 10)
        XCTAssertEqual(ladder.nearest(to: 0.7), 0.5)
        XCTAssertEqual(ladder.nearest(to: 0.71), 1, "0.5와 1 의 기하 중간은 0.707")
        XCTAssertEqual(ladder.nearest(to: 1.4), 1)
        XCTAssertEqual(ladder.nearest(to: 1.5), 2)
        XCTAssertEqual(ladder.nearest(to: 3.1), 2, "2와 5 의 기하 중간은 3.16")
        XCTAssertEqual(ladder.nearest(to: 3.2), 5)
        XCTAssertEqual(ladder.nearest(to: 8), 5, "맨 끝 버튼 너머는 끝 버튼")
        XCTAssertEqual(ladder.nearest(to: 0), 0.5)
    }

    // MARK: 버튼 램프

    func testRampTakesAboutTheSameTimeForAnyHop() {
        XCTAssertEqual(ZoomLadder.rampRate(from: 1, to: 2), Float(1 / 0.3), accuracy: 0.01)
        XCTAssertEqual(ZoomLadder.rampRate(from: 5, to: 0.5), Float(log2(10.0) / 0.3), accuracy: 0.01)
        XCTAssertEqual(ZoomLadder.rampRate(from: 1.9, to: 2), 2, "가까우면 너무 느리게 기지 않는다")
        XCTAssertEqual(ZoomLadder.rampRate(from: 0, to: 2), 2)
    }
}
