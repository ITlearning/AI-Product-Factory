import WidgetKit
import SwiftData
import Foundation

struct StreakEntry: TimelineEntry {
    let date: Date
    let streakCount: Int
    let conceptTitle: String?
    let isStudiedToday: Bool
}

struct StreakTimelineProvider: TimelineProvider {

    private static let appGroupID = "group.com.itlearning.codestudy"

    // MARK: - Shared ModelContainer

    private var sharedModelContainer: ModelContainer? {
        let schema = Schema([DailyStreak.self, ConceptProgress.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(Self.appGroupID)
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - TimelineProvider

    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, streakCount: 7, conceptTitle: "옵셔널 체이닝", isStudiedToday: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let entry = fetchCurrentEntry() ?? placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = fetchCurrentEntry() ?? StreakEntry(
            date: .now,
            streakCount: 0,
            conceptTitle: nil,
            isStudiedToday: false
        )

        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - Data Fetching

    @MainActor
    private func fetchCurrentEntry() -> StreakEntry? {
        guard let container = sharedModelContainer else { return nil }
        let context = container.mainContext

        // Fetch streak
        let streakDescriptor = FetchDescriptor<DailyStreak>()
        let streaks = (try? context.fetch(streakDescriptor)) ?? []
        let streak = streaks.first

        let streakCount = streak?.currentStreak ?? 0

        // Check if studied today
        let calendar = Calendar.current
        let isStudiedToday: Bool
        if let lastDate = streak?.lastStudyDate {
            isStudiedToday = calendar.isDateInToday(lastDate)
        } else {
            isStudiedToday = false
        }

        // Fetch the most recently studied concept
        var conceptDescriptor = FetchDescriptor<ConceptProgress>(
            sortBy: [SortDescriptor(\.lastStudiedAt, order: .reverse)]
        )
        conceptDescriptor.fetchLimit = 1
        let concepts = (try? context.fetch(conceptDescriptor)) ?? []
        let conceptTitle = concepts.first?.conceptTitle

        return StreakEntry(
            date: .now,
            streakCount: streakCount,
            conceptTitle: conceptTitle,
            isStudiedToday: isStudiedToday
        )
    }
}
