import SwiftUI
import SwiftData

@main
struct CodeStudyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            StudySession.self,
            ChatMessage.self,
            ConceptProgress.self,
            DailyStreak.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.com.itlearning.codestudy") // App Group for WidgetKit
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct RootView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if profiles.isEmpty {
            // Onboarding flow — will be implemented in Sprint 3
            Text("Onboarding")
        } else {
            // Main tab view — will be implemented in Sprint 3
            Text("Main")
        }
    }
}
