import Foundation

/// 동시에 도는 작업 수를 limit 개로 묶는다. 기다리다 취소되면 자리를 받지 않고 nil 로 빠진다.
public actor AsyncGate {
    private let limit: Int
    private var running = 0
    private var waiters: [(id: UUID, resume: CheckedContinuation<Bool, Never>)] = []

    public init(limit: Int) {
        self.limit = max(1, limit)
    }

    public func run<T: Sendable>(_ operation: @Sendable () async -> T) async -> T? {
        guard await acquire() else { return nil }
        let result = await operation()
        release()
        return result
    }

    private func acquire() async -> Bool {
        guard !Task.isCancelled else { return false }
        if running < limit {
            running += 1
            return true
        }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { c in
                waiters.append((id, c))
            }
        } onCancel: {
            Task { await self.dropWaiter(id) }
        }
    }

    // 자리는 넘겨주기만 한다 — running 을 줄였다 늘리면 그 사이 새로 온 작업이 새치기한다.
    private func release() {
        if waiters.isEmpty {
            running -= 1
        } else {
            waiters.removeFirst().resume.resume(returning: true)
        }
    }

    private func dropWaiter(_ id: UUID) {
        guard let i = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: i).resume.resume(returning: false)
    }
}
