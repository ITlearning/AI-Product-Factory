import Foundation
import SwiftData

@MainActor
@Observable
final class ProgressViewModel {

    // MARK: - State

    struct State {
        var concepts: [ConceptProgressItem] = []
        var totalStudied: Int = 0
        var totalMastered: Int = 0
        var streakData: [Date: StudyDay] = [:]  // calendar heatmap
        /// True while `loadProgress` is in flight. Replaces the dead
        /// `!isMultiple(of: 1)` heuristic in ProgressDashboardView so the
        /// loading spinner branch actually executes.
        var isLoading: Bool = false
    }

    struct ConceptProgressItem: Identifiable {
        let id: String
        let title: String
        let category: String
        let isMastered: Bool
        let studiedCount: Int
    }

    struct StudyDay {
        let date: Date
        let sessionCount: Int
        let hasMastery: Bool
    }

    // MARK: - Actions

    enum Action {
        case loadProgress
    }

    // MARK: - Published State

    private(set) var state = State()

    // MARK: - Dependencies

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Action Handler

    func handle(_ action: Action) async {
        switch action {
        case .loadProgress:
            await loadProgress()
        }
    }

    // MARK: - Private

    private func loadProgress() async {
        state.isLoading = true
        defer { state.isLoading = false }

        // Cycle 3+ — 현재 사용자 트랙 기준으로 ConceptProgress / StudySession을
        // 모두 필터링. 트랙 전환 시 기록 탭이 해당 트랙의 진척만 보여줌.
        // 1.0.x 데이터(track 미설정)는 모두 .swift로 backfill되어 있음.
        let userTrack = fetchUserTrack()
        let trackRaw = userTrack.rawValue

        // 1. Load ConceptProgress entries for current track only
        let conceptDescriptor = FetchDescriptor<ConceptProgress>(
            predicate: #Predicate { $0.track == trackRaw },
            sortBy: [SortDescriptor(\.conceptTitle)]
        )
        let progresses = (try? modelContext.fetch(conceptDescriptor)) ?? []

        state.concepts = progresses.map { progress in
            ConceptProgressItem(
                id: progress.conceptID,
                title: progress.conceptTitle,
                category: progress.category,
                isMastered: progress.isMastered,
                studiedCount: progress.studiedCount
            )
        }

        state.totalStudied = progresses.count
        state.totalMastered = progresses.filter(\.isMastered).count

        // 2. Build calendar heatmap from current-track StudySessions only
        let sessionDescriptor = FetchDescriptor<StudySession>(
            predicate: #Predicate { $0.track == trackRaw },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        let sessions = (try? modelContext.fetch(sessionDescriptor)) ?? []

        let calendar = Calendar.current
        var dayMap: [Date: (count: Int, hasMastery: Bool)] = [:]

        for session in sessions {
            let day = calendar.startOfDay(for: session.startedAt)
            var entry = dayMap[day] ?? (count: 0, hasMastery: false)
            entry.count += 1
            if session.completion == .mastered {
                entry.hasMastery = true
            }
            dayMap[day] = entry
        }

        state.streakData = dayMap.reduce(into: [:]) { result, pair in
            result[pair.key] = StudyDay(
                date: pair.key,
                sessionCount: pair.value.count,
                hasMastery: pair.value.hasMastery
            )
        }
    }

    /// 현재 사용자 트랙. UserProfile 미설정 또는 invalid 값은 .swift fallback.
    /// (S2 결정: streak는 글로벌 유지. 여기서 track은 ConceptProgress/StudySession
    /// 필터링용으로만 사용.)
    private func fetchUserTrack() -> TrackType {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(descriptor).first else {
            return .swift
        }
        return profile.track
    }
}
