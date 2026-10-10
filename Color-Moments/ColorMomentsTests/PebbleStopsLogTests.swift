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
