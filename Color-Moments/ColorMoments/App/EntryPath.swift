import Foundation

@MainActor
final class EntryPath {
    static let shared = EntryPath()
    private var marks: Set<Telemetry.Path> = []
    private var scheduled: Task<Void, Never>?
    private static let order: [Telemetry.Path] = [.notice, .control, .widget]

    func mark(_ p: Telemetry.Path) { marks.insert(p) }

    func resolve() -> Telemetry.Path {
        defer { marks.removeAll() }
        return Self.order.first(where: marks.contains) ?? .icon
    }

    /// 진입 한 번 = 이벤트 한 번 — 대기 중인 예약이 있으면 새로 만들지 않는다.
    func sendAfterGrace(grace: Duration = .milliseconds(500),
                        send: @escaping (Telemetry.Path) -> Void = { Telemetry.send(.appEntered($0)) }) {
        guard scheduled == nil else { return }
        scheduled = Task { @MainActor in
            try? await Task.sleep(for: grace)   // 콜드 스타트에 didReceive·onOpenURL 이 늦게 와도 잡게
            send(resolve())
            scheduled = nil
        }
    }

    /// 대기 중인 전송이 없으면 남은 표시를 버린다 — 늦게 온 표시가 다음 무관한 진입에 붙지 않게.
    func clearIfIdle() {
        if scheduled == nil { marks.removeAll() }
    }
}
