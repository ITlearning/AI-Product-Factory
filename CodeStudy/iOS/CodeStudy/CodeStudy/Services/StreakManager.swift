import Foundation
import SwiftData
import Observation

// MARK: - StreakManager

@Observable
final class StreakManager {
    private(set) var currentStreak: Int = 0
    private(set) var longestStreak: Int = 0

    init() {}

    /// Called only when the user achieves mastery in a session.
    @MainActor
    func recordMastery(modelContext: ModelContext) {
        let streak = fetchOrCreateStreak(modelContext: modelContext)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = streak.lastStudyDate {
            let lastDay = calendar.startOfDay(for: lastDate)

            if lastDay == today {
                // Same day — no change
                syncFromModel(streak)
                return
            }

            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysBetween == 1 {
                // Consecutive day — increment
                streak.currentStreak += 1
            } else {
                // Gap — reset to 1
                streak.currentStreak = 1
            }
        } else {
            // First ever study
            streak.currentStreak = 1
        }

        streak.lastStudyDate = Date()
        streak.longestStreak = max(streak.longestStreak, streak.currentStreak)

        try? modelContext.save()
        syncFromModel(streak)
    }

    /// Loads current streak data from SwiftData.
    @MainActor
    func loadStreak(modelContext: ModelContext) {
        let streak = fetchOrCreateStreak(modelContext: modelContext)

        // Check if streak is still valid (no gap since last study)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = streak.lastStudyDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysBetween > 1 {
                // Streak broken — reset for display but don't persist until next mastery
                currentStreak = 0
                longestStreak = streak.longestStreak
                return
            }
        }

        syncFromModel(streak)
    }

    // MARK: - Private

    @MainActor
    private func fetchOrCreateStreak(modelContext: ModelContext) -> DailyStreak {
        let descriptor = FetchDescriptor<DailyStreak>()
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let streak = DailyStreak()
        modelContext.insert(streak)
        try? modelContext.save()
        return streak
    }

    private func syncFromModel(_ streak: DailyStreak) {
        currentStreak = streak.currentStreak
        longestStreak = streak.longestStreak
    }
}
