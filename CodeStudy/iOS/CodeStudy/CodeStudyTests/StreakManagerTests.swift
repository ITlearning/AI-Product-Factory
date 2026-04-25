import Testing
import Foundation
import SwiftData
@testable import CodeStudy

@MainActor
@Suite("StreakManager Tests")
struct StreakManagerTests {

    // MARK: - Helpers

    private func makeModelContext() throws -> ModelContext {
        let schema = Schema([
            UserProfile.self,
            StudySession.self,
            ChatMessage.self,
            ConceptProgress.self,
            DailyStreak.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Returns a fresh, isolated UserDefaults backed by a unique suite
    /// name so tests don't leak state into each other or the standard
    /// suite used by the running app.
    private func makeUserDefaults() -> UserDefaults {
        let suite = "StreakManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func seedStreak(
        in context: ModelContext,
        currentStreak: Int,
        freezeCount: Int,
        lastStudyDate: Date?
    ) throws -> DailyStreak {
        let streak = DailyStreak()
        streak.currentStreak = currentStreak
        streak.longestStreak = currentStreak
        streak.freezeCount = freezeCount
        streak.lastStudyDate = lastStudyDate
        context.insert(streak)
        try context.save()
        return streak
    }

    // MARK: - Critical path: streak breakage triggers freeze

    /// Critical test #3 from eng-review: verifies the user-visible
    /// freeze auto-apply behavior. Streak at N days, last session was
    /// the day before yesterday (skipped one full day), 1 freeze in
    /// inventory → freeze consumed, streak preserved, toast flag set.
    @Test func test_streakBreakage_appliesFreezeAutomatically() throws {
        let context = try makeModelContext()
        let defaults = makeUserDefaults()
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: today)!

        let n = 5
        _ = try seedStreak(
            in: context,
            currentStreak: n,
            freezeCount: 1,
            lastStudyDate: dayBeforeYesterday
        )

        let manager = StreakManager()
        let result = manager.checkAndApplyFreeze(
            modelContext: context,
            userDefaults: defaults,
            now: now
        )

        #expect(result == .applied)
        #expect(manager.currentStreak == n, "streak must be preserved")
        #expect(manager.freezeCount == 0, "freeze must be consumed")
        #expect(defaults.bool(forKey: StreakManager.freezeUsedYesterdayKey) == true)

        // Persistence sanity check.
        let persisted = try context.fetch(FetchDescriptor<DailyStreak>()).first
        #expect(persisted?.freezeCount == 0)
        #expect(persisted?.currentStreak == n)
    }

    // MARK: - Edge: no freezes available

    @Test func test_streakBreakage_withoutFreeze_returnsNoFreezes() throws {
        let context = try makeModelContext()
        let defaults = makeUserDefaults()
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: today)!

        _ = try seedStreak(
            in: context,
            currentStreak: 3,
            freezeCount: 0,
            lastStudyDate: dayBeforeYesterday
        )

        let manager = StreakManager()
        let result = manager.checkAndApplyFreeze(
            modelContext: context,
            userDefaults: defaults,
            now: now
        )

        #expect(result == .noFreezesAvailable)
        #expect(defaults.bool(forKey: StreakManager.freezeUsedYesterdayKey) == false)
    }

    // MARK: - Idempotency

    @Test func test_checkAndApplyFreeze_isIdempotentWithinLaunch() throws {
        let context = try makeModelContext()
        let defaults = makeUserDefaults()
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: today)!

        _ = try seedStreak(
            in: context,
            currentStreak: 4,
            freezeCount: 2,
            lastStudyDate: dayBeforeYesterday
        )

        let manager = StreakManager()
        let first = manager.checkAndApplyFreeze(
            modelContext: context,
            userDefaults: defaults,
            now: now
        )
        let second = manager.checkAndApplyFreeze(
            modelContext: context,
            userDefaults: defaults,
            now: now
        )

        #expect(first == .applied)
        #expect(second == .notNeeded, "second call within launch must be a no-op")
        #expect(manager.freezeCount == 1, "only one freeze consumed across two calls")
    }

    // MARK: - Not needed

    @Test func test_checkAndApplyFreeze_returnsNotNeededWhenStudiedToday() throws {
        let context = try makeModelContext()
        let defaults = makeUserDefaults()
        let now = Date()

        _ = try seedStreak(
            in: context,
            currentStreak: 7,
            freezeCount: 1,
            lastStudyDate: now
        )

        let manager = StreakManager()
        let result = manager.checkAndApplyFreeze(
            modelContext: context,
            userDefaults: defaults,
            now: now
        )

        #expect(result == .notNeeded)
        #expect(manager.freezeCount == 1, "freeze must NOT be consumed")
    }
}
