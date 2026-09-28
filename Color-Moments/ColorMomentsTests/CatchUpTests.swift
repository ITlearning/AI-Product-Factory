import XCTest
@testable import ColorMoments

/// 시작 .task 와 active 전환이 같이 불러도 맞추기가 두 벌 겹쳐 돌지 않는지.
@MainActor
final class CatchUpTests: XCTestCase {

    private final class Probe {
        var running = 0, maxRunning = 0, passes = 0
    }

    private func catchUp(_ probe: Probe, settle: Duration = .zero) -> CatchUp {
        CatchUp(firstSettle: settle, pause: { await Task.yield() }, steps: [
            {
                probe.running += 1
                probe.maxRunning = max(probe.maxRunning, probe.running)
                try? await Task.sleep(nanoseconds: 20_000_000)
                probe.running -= 1
                probe.passes += 1
            },
        ])
    }

    /// 시작 때 두 곳에서 부르면 한 번만 돈다.
    func testLaunchTriggersAreMerged() async {
        let probe = Probe()
        let c = catchUp(probe, settle: .milliseconds(30))
        async let a: Void = c.run()
        async let b: Void = c.run()
        _ = await (a, b)
        XCTAssertEqual(probe.passes, 1)
        XCTAssertEqual(probe.maxRunning, 1)
    }

    /// 도는 중에 여러 번 부르면 끝난 뒤 한 번만 더 — 동시에 두 벌은 없다.
    func testRequestsDuringWorkRunOnceMore() async {
        let probe = Probe()
        let c = catchUp(probe)
        let first = Task { await c.run() }
        try? await Task.sleep(nanoseconds: 5_000_000)
        async let x: Void = c.run()
        async let y: Void = c.run()
        _ = await (x, y)
        await first.value
        XCTAssertEqual(probe.passes, 2)
        XCTAssertEqual(probe.maxRunning, 1)
        await c.run()
        XCTAssertEqual(probe.passes, 3, "쉬는 중이면 새로 돈다")
    }
}
