import Foundation
import SwiftData

@Model
final class DailyStreak {
    @Attribute(.unique) var id: UUID
    var currentStreak: Int
    var longestStreak: Int
    var lastStudyDate: Date?
    /// Number of streak freezes the user currently has in inventory.
    /// Auto-consumed by `StreakManager.checkAndApplyFreeze()` when a
    /// streak would otherwise break. Default 0 for backwards compat
    /// with existing 1.0.x users (SwiftData lightweight migration).
    var freezeCount: Int = 0
    /// Last date a freeze was issued to the user. Used by the weekly
    /// grant policy (1 freeze / week max) to avoid stacking.
    var lastFreezeGrantDate: Date?

    init() {
        self.id = UUID()
        self.currentStreak = 0
        self.longestStreak = 0
        self.freezeCount = 0
    }
}
