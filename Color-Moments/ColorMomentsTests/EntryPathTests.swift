import XCTest
@testable import ColorMoments

@MainActor
final class EntryPathTests: XCTestCase {
    func testNoMarkIsIcon() { XCTAssertEqual(EntryPath().resolve(), .icon) }

    func testPriorityNoticeFirst() {
        let e = EntryPath(); e.mark(.widget); e.mark(.control); e.mark(.notice)
        XCTAssertEqual(e.resolve(), .notice, "알림을 눌러 열면서 다른 표시가 겹쳐도 알림으로 센다")
        XCTAssertEqual(e.resolve(), .icon, "한 번 읽으면 비운다 — 다음 진입에 남지 않게")
    }

    func testControlBeforeWidget() {
        let e = EntryPath(); e.mark(.widget); e.mark(.control)
        XCTAssertEqual(e.resolve(), .control)
    }
}
