import Foundation
import SwiftData

// MARK: - SessionManager

struct SessionManager {
    static let dailySessionLimit = 10

    // MARK: - Session Lifecycle

    @MainActor
    static func createSession(
        conceptID: String,
        conceptTitle: String,
        track: TrackType,
        modelContext: ModelContext
    ) -> StudySession {
        let session = StudySession(
            conceptID: conceptID,
            conceptTitle: conceptTitle,
            track: track
        )
        modelContext.insert(session)
        try? modelContext.save()
        return session
    }

    @MainActor
    static func completeSession(
        session: StudySession,
        completionType: CompletionType,
        summary: String?,
        modelContext: ModelContext
    ) {
        session.endedAt = Date()
        session.completion = completionType
        session.summaryText = summary

        // Increment daily session count
        if let profile = fetchProfile(modelContext: modelContext) {
            resetDailyCountIfNeeded(profile: profile)
            profile.dailySessionCount += 1
        }

        try? modelContext.save()
    }

    @MainActor
    static func abandonSession(
        session: StudySession,
        modelContext: ModelContext
    ) {
        session.endedAt = Date()
        session.completion = .abandoned
        try? modelContext.save()
    }

    // MARK: - Concept Progress

    @MainActor
    static func updateConceptProgress(
        conceptID: String,
        conceptTitle: String,
        category: String,
        track: TrackType,
        mastered: Bool,
        modelContext: ModelContext
    ) {
        let predicate = #Predicate<ConceptProgress> { $0.conceptID == conceptID }
        let descriptor = FetchDescriptor<ConceptProgress>(predicate: predicate)

        let progress: ConceptProgress
        if let existing = try? modelContext.fetch(descriptor).first {
            progress = existing
        } else {
            progress = ConceptProgress(
                conceptID: conceptID,
                conceptTitle: conceptTitle,
                category: category,
                track: track
            )
            modelContext.insert(progress)
        }

        progress.studiedCount += 1
        progress.lastStudiedAt = Date()
        if mastered {
            progress.masteredCount += 1
            progress.isMastered = true
        }

        try? modelContext.save()
    }

    // MARK: - Daily Limit

    @MainActor
    static func canStartNewSession(modelContext: ModelContext) -> Bool {
        guard let profile = fetchProfile(modelContext: modelContext) else {
            return true
        }
        resetDailyCountIfNeeded(profile: profile)
        return profile.dailySessionCount < dailySessionLimit
    }

    static func resetDailyCountIfNeeded(profile: UserProfile) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastReset = calendar.startOfDay(for: profile.lastSessionCountResetDate)

        if today > lastReset {
            profile.dailySessionCount = 0
            profile.lastSessionCountResetDate = Date()
        }
    }

    // MARK: - Private Helpers

    @MainActor
    private static func fetchProfile(modelContext: ModelContext) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        return try? modelContext.fetch(descriptor).first
    }
}
