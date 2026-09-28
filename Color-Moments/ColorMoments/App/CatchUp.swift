import Foundation

/// 입양·정리·cloudID 는 순서대로, 위젯 맞추기는 그 셋과 무관하게 바로 한 차례 돈다.
/// 시작 .task 와 active 전환이 같은 순간에 두 벌 돌지 않게 겹치는 요청은 한 차례로 합친다.
/// 맨 처음 차례는 firstSettle 만큼 쉬었다 시작하고(첫 화면이 먼저 그려지게), 단계 사이마다 한 프레임 쉰다.
@MainActor
final class CatchUp {

    struct Step {
        let budget: Duration
        let run: () async -> Void
    }

    private enum Phase { case idle, settling, working }

    private let steps: [Step]
    private let widgetSync: () async -> Void
    private let pause: () async -> Void
    private var phase = Phase.idle
    private var again = false
    private var pass: Task<Void, Never>?
    private var firstSettle: Duration?

    init(firstSettle: Duration = .milliseconds(350), pause: @escaping () async -> Void = FramePause.next,
         steps: [Step], widgetSync: @escaping () async -> Void) {
        self.firstSettle = firstSettle
        self.pause = pause
        self.steps = steps
        self.widgetSync = widgetSync
    }

    /// 아직 시작 전인 차례에 들어온 요청은 그 차례에 합친다. 이미 돌고 있으면 끝난 뒤 한 번만 더 돈다.
    func run() async {
        switch phase {
        case .settling:
            await pass?.value
            return
        case .working:
            again = true
            await pass?.value
            return
        case .idle:
            break
        }
        phase = .settling
        let task = Task { @MainActor in await self.loop() }
        pass = task
        await task.value
    }

    private func loop() async {
        if let firstSettle {
            self.firstSettle = nil
            try? await Task.sleep(for: firstSettle)
        }
        repeat {
            phase = .working
            again = false
            // 위젯 맞추기는 입양·정리·cloudID 체인과 무관하게 이 차례에서 바로 한 번 — 그 체인이 늦어도 기다리지 않는다.
            async let widget: Void = widgetSync()
            for step in steps {
                await runWithBudget(step)
                await pause()
            }
            await widget
        } while again
        phase = .idle
        pass = nil
    }

    /// 상한을 넘으면 그 단계는 배경에서 계속 돌게 두고(취소하지 않는다) 기다리지 않은 채 다음 단계로 넘어간다.
    private func runWithBudget(_ step: Step) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let resumer = Resumer(continuation)
            Task { @MainActor in
                await step.run()
                resumer.resume()
            }
            Task { @MainActor in
                try? await Task.sleep(for: step.budget)
                resumer.resume()
            }
        }
    }

    /// 일·상한 두 갈래 중 먼저 끝난 쪽만 이어간다 — 둘 다 부를 수 있어 한 번만 넘기게 막는다.
    @MainActor
    private final class Resumer {
        private var continuation: CheckedContinuation<Void, Never>?
        init(_ continuation: CheckedContinuation<Void, Never>) { self.continuation = continuation }
        func resume() {
            guard let c = continuation else { return }
            continuation = nil
            c.resume()
        }
    }
}
