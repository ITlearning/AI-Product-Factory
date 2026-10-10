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

    func testClearIfIdleDropsStaleMarks() {
        let e = EntryPath(); e.mark(.notice)
        e.clearIfIdle()
        XCTAssertEqual(e.resolve(), .icon, "대기 중 전송이 없으면 늦게 온 표시를 버린다")
    }

    func testClearIfIdleKeepsMarksWhilePending() async {
        let e = EntryPath()
        let sent = expectation(description: "sent")
        var got: Telemetry.Path?
        e.sendAfterGrace(grace: .milliseconds(50)) { got = $0; sent.fulfill() }
        e.mark(.widget)
        e.clearIfIdle()
        await fulfillment(of: [sent], timeout: 2)
        XCTAssertEqual(got, .widget, "대기 중이면 그 전송이 resolve 한다 — 지우지 않는다")
    }

    func testSecondScheduleWhilePendingSendsOnce() async {
        let e = EntryPath()
        let sent = expectation(description: "sent"); sent.expectedFulfillmentCount = 1
        sent.assertForOverFulfill = true
        e.sendAfterGrace(grace: .milliseconds(50)) { _ in sent.fulfill() }
        e.sendAfterGrace(grace: .milliseconds(50)) { _ in sent.fulfill() }
        await fulfillment(of: [sent], timeout: 2)
        try? await Task.sleep(for: .milliseconds(150))
    }
}
