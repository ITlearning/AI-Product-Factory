import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(String(localized: "tab.learn", defaultValue: "학습"), systemImage: "book.fill", value: 0) {
                NavigationStack {
                    DailyChallengeView()
                }
            }
            Tab(String(localized: "tab.progress", defaultValue: "기록"), systemImage: "chart.bar.fill", value: 1) {
                NavigationStack {
                    ProgressDashboardView()
                }
            }
            Tab(String(localized: "tab.settings", defaultValue: "설정"), systemImage: "gearshape.fill", value: 2) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(Color.warmOrange)
    }
}

#Preview {
    MainTabView()
}
