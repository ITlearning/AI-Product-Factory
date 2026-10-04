import XCTest
@testable import ColorMoments

final class LunarDaysTests: XCTestCase {
    override func tearDown() { LunarDays.table = LunarDays.load(); super.tearDown() }

    func testKeysComeFromTheTable() {
        LunarDays.table = ["2026-02-16": ["12-29", "12-last"], "2026-02-17": ["01-01"]]
        XCTAssertEqual(LunarDays.keys(on: "2026-02-16"), ["12-29", "12-last"])
        XCTAssertEqual(LunarDays.keys(on: "2026-02-15"), [])
    }
}
