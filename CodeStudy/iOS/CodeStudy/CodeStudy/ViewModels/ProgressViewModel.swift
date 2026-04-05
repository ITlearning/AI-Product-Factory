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
        // 1. Load all ConceptProgress entries
        let conceptDescriptor = FetchDescriptor<ConceptProgress>(
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

        // 2. Build calendar heatmap from StudySessions
        let sessionDescriptor = FetchDescriptor<StudySession>(
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
}
