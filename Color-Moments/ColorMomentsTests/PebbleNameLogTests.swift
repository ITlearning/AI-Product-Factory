import XCTest
@testable import ColorMoments

final class PebbleNameLogTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suite = ""
    private var saved: PebbleNameLog!

    override func setUp() {
        suite = "pebble-names-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        saved = PebbleNaming.stamps
        PebbleNaming.stamps = PebbleNameLog(defaults: defaults)
    }

    override func tearDown() {
        PebbleNaming.stamps = saved
        defaults.removePersistentDomain(forName: suite)
    }

    private let acorn = PebbleName(name: "도토리", line: "작은 것에도 가을이 다 들어 있어요.")
    private let chestnut = PebbleName(name: "밤송이", line: "가시 안에 단단한 게 있어요.")

    private func moment(_ hex: String, dayKey: String) -> Moment {
        var c = Calendar(identifier: .gregorian); c.timeZone = .current
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        let date = c.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))!
        return Moment(capturedAt: date, colorHex: hex, fileName: "\(hex).jpg", source: .app)
    }

    func testStampedOnceAndKept() {
        let log = PebbleNaming.stamps
        log.stamp("2026-09-22", acorn)
        log.stamp("2026-09-22", chestnut)
        XCTAssertEqual(PebbleNameLog(defaults: defaults).name(on: "2026-09-22"), acorn, "처음 찍은 이름이 남는다")
    }

    func testTwoDevicesMeetOnTheSameName() {
        let a = PebbleNameLog(defaults: UserDefaults(suiteName: suite + "-a")!)
        let b = PebbleNameLog(defaults: UserDefaults(suiteName: suite + "-b")!)
        a.stamp("d", chestnut)
        b.stamp("d", acorn)
        a.applyRemote(dayKey: "d", name: acorn)
        b.applyRemote(dayKey: "d", name: chestnut)
        XCTAssertEqual(a.name(on: "d"), b.name(on: "d"), "받는 순서와 상관없이 같은 이름으로 모인다")
        XCTAssertEqual(a.name(on: "d"), acorn, "가나다순으로 앞선 쪽")
        UserDefaults().removePersistentDomain(forName: suite + "-a")
        UserDefaults().removePersistentDomain(forName: suite + "-b")
    }

    func testStampBeatsTheCalculation() {
        let day = [moment("#8B5A2B", dayKey: "2025-11-16")]
        let computed = PebbleNaming.name(for: day)
        XCTAssertNotNil(computed)
        PebbleNaming.stamps.stamp("2025-11-16", PebbleName(name: "옛이름", line: "목록에서 빠진 이름"))
        XCTAssertEqual(PebbleNaming.name(for: day)?.name, "옛이름", "목록·색 구간이 바뀌어도 받은 이름은 그대로")
        XCTAssertNil(PebbleNaming.name(for: []), "사진이 없으면 이름도 없다 — 도장이 있어도")
    }

    func testGiftedDaysWithoutAStampGetTodaysName() {
        let days = ["2026-09-20": [moment("#3366AA", dayKey: "2026-09-20")],
                    "2026-09-21": [moment("#AA6633", dayKey: "2026-09-21")],
                    "2026-09-22": [moment("#66AA33", dayKey: "2026-09-22")]]
        PebbleNaming.stamps.stamp("2026-09-21", acorn)
        let before20 = PebbleNaming.name(for: days["2026-09-20"]!)
        PebbleNaming.stampGifted(dayKeys: days.keys.sorted(), isGifted: { $0 <= "2026-09-21" }, moments: { days[$0] ?? [] })
        XCTAssertEqual(PebbleNaming.stamps.name(on: "2026-09-20"), before20, "받은 날은 지금 이름으로 굳는다")
        XCTAssertEqual(PebbleNaming.stamps.name(on: "2026-09-21"), acorn, "이미 찍힌 도장은 그대로")
        XCTAssertNil(PebbleNaming.stamps.name(on: "2026-09-22"), "아직 안 받은 날은 찍지 않는다")
    }
}
