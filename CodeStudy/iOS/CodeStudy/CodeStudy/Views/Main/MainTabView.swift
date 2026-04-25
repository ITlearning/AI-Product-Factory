import SwiftUI
import TipKit

struct MainTabView: View {
    @State private var selectedTab = 0

    /// 탭바의 History 탭 위에 popover로 떠서 신규 기능 안내.
    /// 사용자가 History를 한 번 열면 영구 dismiss.
    private let historyTabTip = HistoryTabTip()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(String(localized: "tab.learn", defaultValue: "학습"), systemImage: "book.fill", value: 0) {
                NavigationStack {
                    DailyChallengeView()
                        // Learn 탭에 머무는 사용자에게 신규 기능을 발견시키기 위해
                        // 컨텐츠 하단 safe area에 banner 형태로 TipView 노출.
                        // popoverTip 대비 장점: 위치/크기 제어 가능, 탭바 가리지 않음.
                        // 사용자가 X 닫기 누르거나 History 탭 진입하면 invalidate.
                        .safeAreaInset(edge: .bottom) {
                            TipView(historyTabTip)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }
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
        .onChange(of: selectedTab) { _, newTab in
            // History 탭 진입 즉시 tip 영구 dismiss.
            if newTab == 1 {
                HistoryTabTip.hasOpenedHistory = true
                historyTabTip.invalidate(reason: .actionPerformed)
            }
        }
    }
}

#Preview {
    MainTabView()
}
