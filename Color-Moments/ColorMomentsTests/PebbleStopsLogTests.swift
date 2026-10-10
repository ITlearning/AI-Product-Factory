import XCTest
@testable import ColorMoments

final class PebbleStopsLogTests: XCTestCase {
    private func log() -> PebbleStopsLog { PebbleStopsLog(defaults: UserDefaults(suiteName: "stops-\(UUID())")!) }
    private let a = [DayGradient.Stop(location: 0.3, hex: "#E9B07D"), DayGradient.Stop(location: 0.7, hex: "#4C6C81")]
    private let b = [DayGradient.Stop(location: 0.5, hex: "#111111")]

    func testStampOnGiftUsesPaletteRuleEvenForGiftedDay() {
        let l = log()
        var m = Moment(capturedAt: Date(timeIntervalSince1970: 1_791_000_000), colorHex: "#E9B07D", fileName: "a.jpg", source: .app)
        m.palette = ["#E9B07D:70", "#4C6C81:30"]
        l.stampOnGift(m.dayKey, moments: [m])
        XCTAssertEqual(l.stops(on: m.dayKey)?.map(\.hex), ["#E9B07D", "#4C6C81"], "1.1.2 가 직접 증정한 날 — 증정 장면에 뜬 새 규칙 그대로 굳힌다")
    }

    private func moment(_ day: Int, palette: [String]? = ["#E9B07D:70", "#4C6C81:30"]) -> Moment {
        var m = Moment(capturedAt: Date(timeIntervalSince1970: 1_791_000_000 + Double(day) * 86_400), colorHex: "#E9B07D", fileName: "a.jpg", source: .app)
        m.palette = palette
        return m
    }

    func testSkippedDaysGetStampedBeforeTheGift() {
        let l = log()
        let days = (0..<5).map { moment($0) }
        let keys = days.map(\.dayKey)
        l.stampSkipped(before: keys[3], dayKeys: keys, wasGifted: { $0 == keys[0] },
                       moments: { k in days.filter { $0.dayKey == k } })
        XCTAssertNil(l.stops(on: keys[0]), "이미 받았던 날")
        XCTAssertEqual(l.stops(on: keys[1])?.map(\.hex), ["#E9B07D", "#4C6C81"], "건너뛴 날은 새 규칙으로")
        XCTAssertNotNil(l.stops(on: keys[2]))
        XCTAssertNil(l.stops(on: keys[3]), "증정일 자신은 stampOnGift 몫")
        XCTAssertNil(l.stops(on: keys[4]), "이후 날")
    }

    func testSkippedKeepsExistingStampAndEmptyDays() {
        let l = log()
        let d = [moment(0), moment(1)]
        let keys = d.map(\.dayKey) + ["2000-01-01"]
        l.stamp(keys[0], b)
        l.stampSkipped(before: "2999-01-01", dayKeys: keys, wasGifted: { _ in false },
                       moments: { k in d.filter { $0.dayKey == k } })
        XCTAssertEqual(l.stops(on: keys[0]), b, "도장 있는 날은 덮지 않는다")
        XCTAssertNotNil(l.stops(on: keys[1]))
        XCTAssertNil(l.stops(on: "2000-01-01"), "사진 없는 날")
    }

    func testStampGiftSkipsAlreadyGiftedDay() {
        let l = log(); let m = moment(0)
        l.stampGift(day: m.dayKey, dayKeys: [m.dayKey], wasGifted: { _ in true }, moments: { _ in [m] })
        XCTAssertNil(l.stops(on: m.dayKey), "다른 기기가 바닥선을 올렸으면 색을 바꾸지 않는다")
        l.stampGift(day: m.dayKey, dayKeys: [m.dayKey], wasGifted: { _ in false }, moments: { _ in [m] })
        XCTAssertNotNil(l.stops(on: m.dayKey))
    }

    func testFirstStampStays() {
        let l = log(); l.stamp("2026-10-10", a); l.stamp("2026-10-10", b)
        XCTAssertEqual(l.stops(on: "2026-10-10"), a, "처음 찍은 도장 그대로")
    }

    func testSurvivesRelaunch() {
        let d = UserDefaults(suiteName: "stops-\(UUID())")!
        PebbleStopsLog(defaults: d).stamp("2026-10-10", a)
        XCTAssertEqual(PebbleStopsLog(defaults: d).stops(on: "2026-10-10"), a)
    }

    func testTwoDevicesConvergeOnOneStamp() {
        let one = log(), two = log()
        one.stamp("2026-10-10", a); two.stamp("2026-10-10", b)
        one.applyRemote(dayKey: "2026-10-10", stops: b); two.applyRemote(dayKey: "2026-10-10", stops: a)
        XCTAssertEqual(one.stops(on: "2026-10-10"), two.stops(on: "2026-10-10"), "같은 iCloud 두 기기는 한 도장으로 모인다")
    }

    func testLocalStampNotifiesOnce() {
        let l = log(); var sent: [String] = []
        l.onLocalChange = { sent.append($0) }
        l.stamp("2026-10-10", a); l.stamp("2026-10-10", a)
        XCTAssertEqual(sent, ["2026-10-10"])
    }

    func testStampedValueEqualsReloadedValue() {
        let d = UserDefaults(suiteName: "stops-\(UUID())")!
        let l = PebbleStopsLog(defaults: d)
        l.stamp("2026-10-10", [DayGradient.Stop(location: 0.30004, hex: "#E9B07D")])
        XCTAssertEqual(PebbleStopsLog(defaults: d).stops(on: "2026-10-10"), l.stops(on: "2026-10-10"))
    }

    func testStampRoundsToThreeDecimals() {
        let l = log()
        l.stamp("2026-10-10", [DayGradient.Stop(location: 0.30004, hex: "#E9B07D")])
        XCTAssertEqual(l.stops(on: "2026-10-10"), [DayGradient.Stop(location: 0.3, hex: "#E9B07D")])
    }

    func testApplyRemoteSameValueIsNoChange() {
        let l = log()
        l.stamp("2026-10-10", [DayGradient.Stop(location: 0.30004, hex: "#E9B07D")])
        XCTAssertFalse(l.applyRemote(dayKey: "2026-10-10", stops: [DayGradient.Stop(location: 0.3, hex: "#E9B07D")]))
        XCTAssertFalse(l.applyRemote(dayKey: "2026-10-10", stops: [DayGradient.Stop(location: 0.30004, hex: "#E9B07D")]))
    }
}
