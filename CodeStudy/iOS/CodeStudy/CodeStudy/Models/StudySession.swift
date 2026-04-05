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

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage] = []

    init(conceptID: String, conceptTitle: String) {
        self.id = UUID()
        self.conceptID = conceptID
        self.conceptTitle = conceptTitle
        self.startedAt = Date()
        self.turnCount = 0
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
