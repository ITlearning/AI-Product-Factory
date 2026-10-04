import Foundation

/// 앱 타깃이 꽂는다(ColorMoments/App/WordModel.swift). 확장에는 없다 — nil 이면 규칙.
public enum WordScorer {
    public enum Failure: Error { case unavailable, timedOut }

    public nonisolated(unsafe) static var score: (@Sendable (Moment) async throws -> [String: Float])?

    public static func scores(for m: Moment, within seconds: Double = 2) async throws -> [String: Float] {
        guard let score else { throw Failure.unavailable }
        return try await withThrowingTaskGroup(of: [String: Float].self) { group in
            group.addTask { try await score(m) }
            group.addTask { try await Task.sleep(for: .seconds(seconds)); throw Failure.timedOut }
            defer { group.cancelAll() }
            return try await group.next() ?? [:]
        }
    }
}
