import Foundation

/// 입양·정리·cloudID·위젯 맞추기를 한 줄로 돌린다 — 시작 .task 와 active 전환이 같은 순간에 두 벌 돌지 않게.
/// 맨 처음 차례는 firstSettle 만큼 쉬었다 시작하고(첫 화면이 먼저 그려지게), 단계 사이마다 한 프레임 쉰다.
@MainActor
final class CatchUp {

    private enum Phase { case idle, settling, working }

    private let steps: [() async -> Void]
    private let pause: () async -> Void
    private var phase = Phase.idle
    private var again = false
    private var pass: Task<Void, Never>?
    private var firstSettle: Duration?

    init(firstSettle: Duration = .milliseconds(350), pause: @escaping () async -> Void = FramePause.next,
         steps: [() async -> Void]) {
        self.firstSettle = firstSettle
        self.pause = pause
        self.steps = steps
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
            for step in steps {
                await step()
                await pause()
            }
        } while again
        phase = .idle
        pass = nil
    }
}
