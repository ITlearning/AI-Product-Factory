import XCTest
@testable import ColorMoments

final class MemoriesLastYearTests: XCTestCase {

    func testExactlyOneYearAgoMatches() {
        XCTAssertEqual(Memories.lastYear(today: "2026-09-24", giftedDays: ["2025-09-24"]), "2025-09-24")
    }

    func testThreeDaysBeforeIsStillInWindow() {
        XCTAssertEqual(Memories.lastYear(today: "2026-09-24", giftedDays: ["2025-09-21"]), "2025-09-21")
    }

    func testFourDaysBeforeIsOutsideWindow() {
        XCTAssertNil(Memories.lastYear(today: "2026-09-24", giftedDays: ["2025-09-20"]))
    }

    func testEquidistantCandidatesPickTheEarlierDay() {
        let result = Memories.lastYear(today: "2026-09-24", giftedDays: ["2025-09-25", "2025-09-23"])
        XCTAssertEqual(result, "2025-09-23")
    }

    func testLeapDayAnchorsToFeb28InThePriorYear() {
        // 2028년은 윤년(2/29 존재) — 1년 전(2027)엔 2/29가 없어 2/28을 기준으로 ±3일을 잡는다.
        XCTAssertEqual(Memories.lastYear(today: "2028-02-29", giftedDays: ["2027-03-02"]), "2027-03-02")
        XCTAssertNil(Memories.lastYear(today: "2028-02-29", giftedDays: ["2027-03-04"]))
    }

    func testYearBoundaryWindowCrossesIntoPriorYear() {
        // 1년 전 기준일이 1/2 → 창은 전년 12/30 ~ 1/5.
        XCTAssertEqual(Memories.lastYear(today: "2027-01-02", giftedDays: ["2025-12-30"]), "2025-12-30")
    }

    func testNoCandidateInWindowYieldsNil() {
        XCTAssertNil(Memories.lastYear(today: "2026-09-24", giftedDays: []))
        XCTAssertNil(Memories.lastYear(today: "2026-09-24", giftedDays: ["2025-01-01", "2024-09-24"]))
    }
}

final class MemoriesMonthsTests: XCTestCase {

    func testExcludesCurrentMonth() {
        let days = ["2026-09-20", "2026-09-01", "2026-08-15"]
        XCTAssertEqual(Memories.months(giftedDays: days, today: "2026-09-24"), ["2026-08"])
    }

    func testDedupesAndOrdersNewestFirst() {
        let days = ["2026-08-15", "2026-08-02", "2026-07-01", "2026-07-20"]
        XCTAssertEqual(Memories.months(giftedDays: days, today: "2026-09-24"), ["2026-08", "2026-07"])
    }

    func testOnlyGiftedDaysPassedInAreConsidered() {
        // 함수는 넘어온 giftedDays 를 그대로 믿는다 — 안 받은 날 제외는 호출부(HomeView) 책임.
        XCTAssertEqual(Memories.months(giftedDays: [], today: "2026-09-24"), [])
    }
}

final class MemoriesHandfulLayoutTests: XCTestCase {

    func testCountMatchesRequestedNumberOfPebbles() {
        XCTAssertEqual(Memories.handfulLayout(count: 1, seed: 7).count, 1)
        XCTAssertEqual(Memories.handfulLayout(count: 31, seed: 7).count, 31)
        XCTAssertEqual(Memories.handfulLayout(count: 0, seed: 7).count, 0)
    }

    func testAllPlacementsStayWithinTheUnitCircle() {
        for count in [1, 6, 12, 31] {
            for p in Memories.handfulLayout(count: count, seed: 42) {
                XCTAssertLessThanOrEqual((p.x * p.x + p.y * p.y).squareRoot(), 1.0001,
                                          "count=\(count) 배치가 한 손(원) 밖으로 나갔다")
            }
        }
    }

    func testSameSeedProducesTheSameLayout() {
        let a = Memories.handfulLayout(count: 12, seed: 99)
        let b = Memories.handfulLayout(count: 12, seed: 99)
        XCTAssertEqual(a.count, b.count)
        XCTAssertTrue(zip(a, b).allSatisfy { $0 == $1 })
    }

    func testDifferentSeedsCanProduceDifferentLayouts() {
        let a = Memories.handfulLayout(count: 12, seed: 1)
        let b = Memories.handfulLayout(count: 12, seed: 2)
        XCTAssertFalse(zip(a, b).allSatisfy { $0 == $1 })
    }
}
