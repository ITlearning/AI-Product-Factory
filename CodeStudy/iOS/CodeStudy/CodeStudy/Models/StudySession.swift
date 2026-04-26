import Foundation
import SwiftData

@Model
final class StudySession {
    @Attribute(.unique) var id: UUID
    var conceptID: String
    var conceptTitle: String
    var startedAt: Date
    var endedAt: Date?
    var completionStatus: String?  // CompletionType rawValue
    var turnCount: Int
    var summaryText: String?

    /// Cycle 3+ — 학습 트랙 (swift / backend / 이후 추가될 직군).
    /// 기존 1.0.x 사용자 세션은 모두 swift 트랙으로 backfill됨 (lightweight migration).
    /// 기록 탭은 현재 사용자 트랙의 세션만 필터링해서 보여줌.
    var track: String = TrackType.swift.rawValue

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage] = []

    init(conceptID: String, conceptTitle: String, track: TrackType = .swift) {
        self.id = UUID()
        self.conceptID = conceptID
        self.conceptTitle = conceptTitle
        self.startedAt = Date()
        self.turnCount = 0
        self.track = track.rawValue
    }

    /// SwiftData에 저장된 raw String을 enum으로 변환. invalid 값은 swift fallback.
    var trackType: TrackType {
        TrackType(rawValue: track) ?? .swift
    }

    var completion: CompletionType? {
        get { completionStatus.flatMap { CompletionType(rawValue: $0) } }
        set { completionStatus = newValue?.rawValue }
    }

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
}

enum CompletionType: String, Codable {
    case mastered
    case manual
    case abandoned
}
