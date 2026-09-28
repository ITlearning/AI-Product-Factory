import XCTest
@testable import ColorMoments

/// 시작 .task 와 active 전환이 같이 불러도 맞추기가 두 벌 겹쳐 돌지 않는지.
@MainActor
final class CatchUpTests: XCTestCase {

    private final class Probe {
        var running = 0, maxRunning = 0, passes = 0
        var widgetRuns = 0
    }

    private func catchUp(_ probe: Probe, settle: Duration = .zero, budget: Duration = .seconds(20)) -> CatchUp {
        CatchUp(firstSettle: settle, pause: { await Task.yield() }, steps: [
            .init(budget: budget) {
                probe.running += 1
                probe.maxRunning = max(probe.maxRunning, probe.running)
                try? await Task.sleep(nanoseconds: 20_000_000)
                probe.running -= 1
                probe.passes += 1
            },
        ], widgetSync: { probe.widgetRuns += 1 })
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

    /// 한 단계가 상한을 넘겨도 뒤 단계는 기다리지 않고 이어 돈다.
    func testSlowStepDoesNotBlockLaterSteps() async {
        actor Order {
            var events: [String] = []
            func record(_ e: String) { events.append(e) }
        }
        let order = Order()
        let c = CatchUp(firstSettle: .zero, pause: { await Task.yield() }, steps: [
            .init(budget: .milliseconds(10)) {
                try? await Task.sleep(nanoseconds: 200_000_000) // 상한을 훌쩍 넘김
                await order.record("slow-finished")
            },
            .init(budget: .seconds(5)) {
                await order.record("next-ran")
            },
        ], widgetSync: { await order.record("widget-ran") })

        let started = Date()
        await c.run()
        let elapsed = Date().timeIntervalSince(started)
        // 느린 단계의 실제 완료(200ms)를 기다리지 않고 상한(10ms) 근처에서 다음 단계·위젯까지 끝난다.
        XCTAssertLessThan(elapsed, 0.15)
        let events = await order.events
        XCTAssertTrue(events.contains("next-ran"))
        XCTAssertTrue(events.contains("widget-ran"))
        XCTAssertFalse(events.contains("slow-finished"), "느린 단계는 아직 배경에서 도는 중이어야 한다")
        // 배경에서 계속 돌던 느린 단계가 결국 끝나는지.
        try? await Task.sleep(nanoseconds: 300_000_000)
        let finalEvents = await order.events
        XCTAssertTrue(finalEvents.contains("slow-finished"))
    }

    /// 위젯 맞추기는 앞 단계 체인이 늦어도 기다리지 않고 그 차례에 바로 돈다.
    func testWidgetSyncIsIndependentOfStepChain() async {
        actor Order {
            var events: [String] = []
            func record(_ e: String) { events.append(e) }
        }
        let order = Order()
        let c = CatchUp(firstSettle: .zero, pause: { await Task.yield() }, steps: [
            .init(budget: .seconds(5)) {
                try? await Task.sleep(nanoseconds: 40_000_000)
                await order.record("step")
            },
        ], widgetSync: { await order.record("widget") })

        await c.run()
        let events = await order.events
        XCTAssertEqual(Set(events), ["step", "widget"])
    }
}
