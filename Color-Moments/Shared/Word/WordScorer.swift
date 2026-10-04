import Foundation

/// 앱 타깃이 꽂는다(ColorMoments/App/WordModel.swift). 확장에는 없다 — nil 이면 규칙.
public enum WordScorer {
    public enum Failure: Error { case unavailable, timedOut }

    public nonisolated(unsafe) static var score: (@Sendable (Moment) async throws -> [String: Float])?

    public static func scores(for m: Moment, within seconds: Double = 2) async throws -> [String: Float] {
        guard let score else { throw Failure.unavailable }
        // 구조적 동시성은 자식이 끝나야 돌아온다 — 취소를 무시하는 추론이 2초 한도를 깨지 않게 따로 띄워 경주시킨다.
        let gate = Gate()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                gate.set(cont)
                Task.detached { gate.finish(await Result { try await score(m) }) }
                Task.detached {
                    try? await Task.sleep(for: .seconds(seconds))
                    gate.finish(.failure(Failure.timedOut))
                }
            }
        } onCancel: { gate.finish(.failure(CancellationError())) }
    }

    private final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var cont: CheckedContinuation<[String: Float], Error>?
        func set(_ c: CheckedContinuation<[String: Float], Error>) { lock.lock(); cont = c; lock.unlock() }
        func finish(_ r: Result<[String: Float], Error>) {
            lock.lock(); let c = cont; cont = nil; lock.unlock()
            c?.resume(with: r)
        }
    }
}

private extension Result where Failure == Error {
    init(_ body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}
