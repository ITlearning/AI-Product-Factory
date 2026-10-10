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
    func sendAfterGrace() {
        guard scheduled == nil else { return }
        scheduled = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))   // 콜드 스타트에 didReceive·onOpenURL 이 늦게 와도 잡게
            Telemetry.send(.appEntered(resolve()))
            scheduled = nil
        }
    }
}
