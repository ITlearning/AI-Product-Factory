import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab(String(localized: "tab.learn", defaultValue: "학습"), systemImage: "book.fill") {
                NavigationStack {
                    DailyChallengeView()
                }
            }
            Tab(String(localized: "tab.progress", defaultValue: "기록"), systemImage: "chart.bar.fill") {
                NavigationStack {
                    ProgressDashboardView()
                }
            }
            Tab(String(localized: "tab.settings", defaultValue: "설정"), systemImage: "gearshape.fill") {
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
