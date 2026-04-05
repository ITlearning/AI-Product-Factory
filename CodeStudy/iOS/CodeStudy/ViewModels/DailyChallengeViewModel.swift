import Foundation
import SwiftData

// MARK: - Concept (curriculum placeholder)

struct Concept: Identifiable, Sendable {
    let id: String
    let title: String
    let category: String
    let level: SwiftLevel
    let description: String
}

// MARK: - ConceptCurriculum Protocol

protocol ConceptCurriculum: Sendable {
    func nextConcept(level: SwiftLevel, masteredIDs: Set<String>) -> Concept?
    func dailyTip(for concept: Concept) -> String?
}

// MARK: - DailyChallengeViewModel

@MainActor
@Observable
final class DailyChallengeViewModel {

    // MARK: - State

    struct State {
        var todayConcept: Concept?
        var streak: Int = 0
        var longestStreak: Int = 0
        var isLoading = true
        var canStartSession = true
        var dailyTip: String?
    }

    // MARK: - Actions

    enum Action {
        case loadTodayConcept
        case startSession
    }

    // MARK: - Published State

    private(set) var state = State()

    // MARK: - Dependencies

    private let curriculum: ConceptCurriculum
    private let modelContext: ModelContext

    /// Set after `startSession` creates one — the View layer reads it.
    private(set) var activeSession: StudySession?

    init(curriculum: ConceptCurriculum, modelContext: ModelContext) {
        self.curriculum = curriculum
        self.modelContext = modelContext
    }

    // MARK: - Action Handler

    func handle(_ action: Action) async {
        switch action {
        case .loadTodayConcept:
            await loadTodayConcept()
        case .startSession:
            await startSession()
        }
    }

    // MARK: - Private

    private func loadTodayConcept() async {
        state.isLoading = true

        // 1. Fetch user profile for level
        let userLevel = fetchUserLevel()

        // 2. Fetch mastered concept IDs
        let masteredIDs = fetchMasteredConceptIDs()

        // 3. Get next concept from curriculum
        let concept = curriculum.nextConcept(level: userLevel, masteredIDs: masteredIDs)
        state.todayConcept = concept

        // 4. Load daily tip
        if let concept {
            state.dailyTip = curriculum.dailyTip(for: concept)
        }

        // 5. Load streak
        loadStreakData()

        // 6. Check daily session limit
        state.canStartSession = checkDailyLimit()

        state.isLoading = false
    }

    private func startSession() async {
        guard state.canStartSession else { return }
        guard let concept = state.todayConcept else { return }

        // Increment daily session count on the profile
        incrementDailySessionCount()

        // Create a new StudySession
        let session = StudySession(conceptID: concept.id, conceptTitle: concept.title)
        modelContext.insert(session)

        do {
            try modelContext.save()
        } catch {
            // Fail silently for now; the View will see no activeSession
            return
        }

        activeSession = session
    }

    // MARK: - Helpers

    private func fetchUserLevel() -> SwiftLevel {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(descriptor).first else {
            return .beginner
        }
        return profile.level
    }

    private func fetchMasteredConceptIDs() -> Set<String> {
        let descriptor = FetchDescriptor<ConceptProgress>(
            predicate: #Predicate { $0.isMastered == true }
        )
        let progresses = (try? modelContext.fetch(descriptor)) ?? []
        return Set(progresses.map(\.conceptID))
    }

    private func loadStreakData() {
        let descriptor = FetchDescriptor<DailyStreak>()
        guard let streak = try? modelContext.fetch(descriptor).first else {
            state.streak = 0
            state.longestStreak = 0
            return
        }
        state.streak = streak.currentStreak
        state.longestStreak = streak.longestStreak
    }

    private func checkDailyLimit() -> Bool {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(descriptor).first else {
            return true
        }

        // Reset counter if day changed
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastReset = calendar.startOfDay(for: profile.lastSessionCountResetDate)

        if lastReset < today {
            profile.dailySessionCount = 0
            profile.lastSessionCountResetDate = Date()
            try? modelContext.save()
        }

        return profile.dailySessionCount < AppConstants.maxSessionsPerDay
    }

    private func incrementDailySessionCount() {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(descriptor).first else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastReset = calendar.startOfDay(for: profile.lastSessionCountResetDate)

        if lastReset < today {
            profile.dailySessionCount = 1
            profile.lastSessionCountResetDate = Date()
        } else {
            profile.dailySessionCount += 1
        }

        try? modelContext.save()
    }
}
