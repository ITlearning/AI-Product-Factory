import XCTest
@testable import ColorMoments

final class OnboardingGiftTests: XCTestCase {

    func testPicksMostRecentDayExcludingToday() {
        let day = OnboardingGift.firstImportDay(existingRecordsWereEmpty: true,
                                                importedDayKeys: ["2026-09-18", "2026-09-20", "2026-09-22"],
                                                today: "2026-09-22")
        XCTAssertEqual(day, "2026-09-20")
    }

    func testTodayOnlyYieldsNil() {
        let day = OnboardingGift.firstImportDay(existingRecordsWereEmpty: true,
                                                importedDayKeys: ["2026-09-22"],
                                                today: "2026-09-22")
        XCTAssertNil(day, "오늘만 담았으면 진행 중 블록이라 증정하지 않는다")
    }

    func testExistingRecordsYieldNil() {
        let day = OnboardingGift.firstImportDay(existingRecordsWereEmpty: false,
                                                importedDayKeys: ["2026-09-20"],
                                                today: "2026-09-22")
        XCTAssertNil(day, "기존 기록이 있었으면 온보딩이 아니다")
    }

    func testEmptyImportYieldsNil() {
        let day = OnboardingGift.firstImportDay(existingRecordsWereEmpty: true,
                                                importedDayKeys: [],
                                                today: "2026-09-22")
        XCTAssertNil(day)
    }
}
