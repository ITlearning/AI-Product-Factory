import XCTest
@testable import ColorMoments

final class ArrivalsTests: XCTestCase {

    func testFirstLoadIsBaselineNotArrival() {
        var a = Arrivals()
        XCTAssertEqual(a.update(ids: [], loaded: false, held: false), [])
        XCTAssertEqual(a.phase("2026-09-01"), .settled, "로드 전엔 기준이 없다")
        XCTAssertEqual(a.update(ids: ["2026-09-02", "2026-09-01"], loaded: true, held: false), [])
        XCTAssertEqual(a.phase("2026-09-01"), .settled)
    }

    func testNewRowsStaggerTopDown() {
        var a = Arrivals()
        _ = a.update(ids: ["d3"], loaded: true, held: false)
        XCTAssertEqual(a.phase("d5"), .pending, "순서를 받기 전 한 프레임은 숨긴다")
        let animated = a.update(ids: ["d5", "d4", "d3"], loaded: true, held: false)
        XCTAssertEqual(animated, ["d5", "d4"])
        XCTAssertEqual(a.phase("d5"), .animate(delay: 0))
        XCTAssertEqual(a.phase("d4"), .animate(delay: Arrivals.stagger))
        XCTAssertEqual(a.phase("d3"), .settled)
        a.finish(["d5"])
        XCTAssertEqual(a.phase("d5"), .settled, "한 번 보여준 뒤엔 스크롤로 다시 봐도 그대로")
    }

    func testOnlyFirstFewAnimateRestSettle() {
        var a = Arrivals()
        _ = a.update(ids: [], loaded: true, held: false)
        let ids = (0..<20).map { "d\($0)" }
        let animated = a.update(ids: ids, loaded: true, held: false)
        XCTAssertEqual(animated, Array(ids.prefix(Arrivals.maxAnimated)))
        XCTAssertEqual(a.phase("d19"), .settled)
    }

    func testHeldRowsWaitHiddenUntilRelease() {
        var a = Arrivals()
        _ = a.update(ids: ["d1"], loaded: true, held: false)
        XCTAssertEqual(a.update(ids: ["d3", "d1"], loaded: true, held: true), [])
        XCTAssertEqual(a.update(ids: ["d3", "d2", "d1"], loaded: true, held: true), [])
        XCTAssertEqual(a.phase("d3"), .pending)
        XCTAssertEqual(a.release(order: ["d3", "d2", "d1"]), ["d3", "d2"])
        XCTAssertEqual(a.phase("d2"), .animate(delay: Arrivals.stagger))
        XCTAssertEqual(a.release(order: ["d3", "d2", "d1"]), [], "두 번 풀지 않는다")
    }

    func testRemovedWhileHeldIsDropped() {
        var a = Arrivals()
        _ = a.update(ids: ["d1"], loaded: true, held: false)
        _ = a.update(ids: ["d2", "d1"], loaded: true, held: true)
        _ = a.update(ids: ["d1"], loaded: true, held: true)
        XCTAssertEqual(a.release(order: ["d1"]), [])
    }

    func testProgressBlockReappearingAnimatesAgain() {
        var a = Arrivals()
        _ = a.update(ids: ["d1"], loaded: true, held: false)
        XCTAssertEqual(a.update(ids: ["progress", "d1"], loaded: true, held: false), ["progress"])
        a.finish(["progress"])
        _ = a.update(ids: ["d0", "d1"], loaded: true, held: false)
        XCTAssertEqual(a.update(ids: ["progress", "d0", "d1"], loaded: true, held: false), ["progress"])
    }
}
