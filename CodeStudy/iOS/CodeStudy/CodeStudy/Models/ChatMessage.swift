import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var role: String  // MessageRole rawValue
    var content: String
    var createdAt: Date
    var orderIndex: Int
    var session: StudySession?

    init(role: MessageRole, content: String, orderIndex: Int) {
        self.id = UUID()
        self.role = role.rawValue
        self.content = content
        self.createdAt = Date()
        self.orderIndex = orderIndex
    }

    var messageRole: MessageRole {
        get { MessageRole(rawValue: role) ?? .user }
        set { role = newValue.rawValue }
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}
