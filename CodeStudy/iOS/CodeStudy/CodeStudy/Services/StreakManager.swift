import Foundation
import SwiftData
import Observation

// MARK: - StreakManager

@Observable
final class StreakManager {
    private(set) var currentStreak: Int = 0
    private(set) var longestStreak: Int = 0
    private(set) var freezeCount: Int = 0

    /// Idempotency guard — `checkAndApplyFreeze` must not double-consume
    /// a freeze if called twice in the same launch (e.g. RootView reappears).
    private var didCheckFreezeThisLaunch = false

    /// UserDefaults key set to `true` when a freeze was auto-applied yesterday.
    /// RootView reads this on app start to show `StreakToast`, then resets it.
    static let freezeUsedYesterdayKey = "freezeUsedYesterday"

    init() {}

    // MARK: - FreezeResult

    /// Result of `checkAndApplyFreeze()`. Used by RootView toast logic
    /// and surfaced in tests for the critical "streak breakage" path.
    enum FreezeResult: Equatable {
        /// Streak was not in danger (today is consecutive or first launch).
        case notNeeded
        /// A freeze was consumed, streak preserved.
        case applied
        /// Streak was in danger but no freezes available — streak resets.
        case noFreezesAvailable
    }

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

        // Weekly freeze grant: at most 1 freeze per 7-day window.
        applyWeeklyFreezeGrantIfDue(streak: streak, today: today)

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
                freezeCount = streak.freezeCount
                return
            }
        }

        syncFromModel(streak)
    }

    // MARK: - Freeze auto-apply

    /// Checks whether the user's streak is in danger (skipped one full day)
    /// and, if so, consumes one freeze to preserve it. Idempotent within a
    /// single app launch — repeated calls return `.notNeeded` after the
    /// first decision is made. Should be called on app start (RootView).
    ///
    /// Behavior matrix:
    /// - lastStudyDate == today → `.notNeeded` (already studied today)
    /// - daysBetween == 0 or 1 → `.notNeeded` (today or yesterday)
    /// - daysBetween == 2 AND freezeCount > 0 → `.applied`, consume 1
    ///   freeze, set `freezeUsedYesterday=true`, push lastStudyDate to
    ///   yesterday so today still extends the streak.
    /// - daysBetween == 2 AND freezeCount == 0 → `.noFreezesAvailable`,
    ///   leave streak as-is (display layer treats >1 day gap as broken).
    /// - daysBetween > 2 → `.noFreezesAvailable` (more than one full day
    ///   missed; freeze only covers a single skipped day per design).
    @MainActor
    @discardableResult
    func checkAndApplyFreeze(
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> FreezeResult {
        if didCheckFreezeThisLaunch {
            return .notNeeded
        }
        didCheckFreezeThisLaunch = true

        let streak = fetchOrCreateStreak(modelContext: modelContext)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        guard let lastDate = streak.lastStudyDate else {
            // No prior study — onboarding flow handles first session.
            syncFromModel(streak)
            return .notNeeded
        }

        let lastDay = calendar.startOfDay(for: lastDate)
        let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        // Consecutive day, today, or future-dated last entry → fine.
        if daysBetween <= 1 {
            syncFromModel(streak)
            return .notNeeded
        }

        // Freeze covers exactly one skipped day. >2 day gap = streak broken
        // beyond rescue (design: freeze 발급 1회/주 → 2일치 freeze 동시 사용 X).
        guard daysBetween == 2 else {
            syncFromModel(streak)
            return .noFreezesAvailable
        }

        // Streak in danger. Consume freeze if available.
        guard streak.freezeCount > 0 else {
            syncFromModel(streak)
            return .noFreezesAvailable
        }

        streak.freezeCount -= 1
        // Push lastStudyDate to "yesterday" so the next mastery today
        // extends the streak as if the user studied yesterday.
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            streak.lastStudyDate = yesterday
        }

        try? modelContext.save()
        userDefaults.set(true, forKey: Self.freezeUsedYesterdayKey)
        syncFromModel(streak)
        return .applied
    }

    // MARK: - Private

    /// Issues 1 freeze per 7-day window (capped at small inventory to
    /// prevent abuse). Called on every mastery — checks the last grant
    /// date so it's idempotent within the window.
    private func applyWeeklyFreezeGrantIfDue(streak: DailyStreak, today: Date) {
        let calendar = Calendar.current
        let maxInventory = 2

        if let lastGrant = streak.lastFreezeGrantDate {
            let daysSinceGrant = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastGrant),
                to: today
            ).day ?? 0
            guard daysSinceGrant >= 7 else { return }
        }

        // Don't stack beyond the cap.
        guard streak.freezeCount < maxInventory else {
            // Still touch lastFreezeGrantDate so the window resets at cap.
            streak.lastFreezeGrantDate = today
            return
        }

        streak.freezeCount += 1
        streak.lastFreezeGrantDate = today
    }

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
        freezeCount = streak.freezeCount
    }
}
