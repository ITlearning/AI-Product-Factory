import Foundation
import SwiftData

@Model
final class DailyStreak {
    @Attribute(.unique) var id: UUID
    var currentStreak: Int
    var longestStreak: Int
    var lastStudyDate: Date?

    init() {
        self.id = UUID()
        self.currentStreak = 0
        self.longestStreak = 0
    }
}
