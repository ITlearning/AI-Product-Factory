import SwiftUI
import SwiftData
import TipKit

@main
struct CodeStudyApp: App {
    init() {
        // TipKit 초기화 — Cycle 2 신규 기능 안내용 (학습 기록 인터랙티브 등).
        // - displayFrequency: .immediate → 조건 충족 시 바로 표시
        // - datastoreLocation: .applicationDefault → 앱 sandbox에 dismiss 상태 영속화
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault),
        ])
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            StudySession.self,
            ChatMessage.self,
            ConceptProgress.self,
            DailyStreak.self,
        ])
        // App Group removed for MVP — widget data sharing will be added
        // in v0.4 when the App Group ID is registered in Apple Developer Portal.
        // groupContainer: .identifier("group.com.itlearning.codestudy")
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// Remote config (인앱 설문 URL/토글). 앱 한 번 켜질 때 한 번 fetch.
    /// `RootView`가 environment로 주입한다.
    @State private var configService = ConfigService(baseURL: AppConstants.apiBaseURL)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(configService)
        }
        .modelContainer(sharedModelContainer)
    }
}

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(ConfigService.self) private var configService

    /// Streak freeze auto-apply runs once per launch. RootView owns the
    /// instance so SwiftUI's `.task` lifecycle matches a single launch.
    @State private var streakManager = StreakManager()
    @State private var showFreezeToast = false

    var body: some View {
        ZStack(alignment: .top) {
            if profiles.isEmpty {
                OnboardingView(modelContext: modelContext)
            } else {
                MainTabView()
            }

            // Freeze-used toast overlays the active screen. Only shown for
            // existing users (currentStreak > 0) — first-time onboarding
            // users never see it because the flag is never set for them.
            if showFreezeToast {
                StreakToast(isPresented: $showFreezeToast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1000)
            }
        }
        .task {
            // 1. Refresh remote config (survey URL / enabled toggle).
            //    Fire-and-forget — fallback to cached or default if it fails.
            //
            //    Note: 이전 1.1.0 plan에는 "기존 마스터자에게 surveyShown=true 자동 설정"
            //    마이그레이션이 있었으나, 정책 반전으로 제거됨. 기존 사용자도 진짜
            //    사용 경험이 있는 핵심 시그널 — 다음 마스터리 시 설문 노출.
            await configService.refreshIfStale()

            // 2. Auto-apply streak freeze if the user skipped yesterday.
            //    Idempotent within a launch — safe even if .task re-fires.
            _ = streakManager.checkAndApplyFreeze(modelContext: modelContext)

            // 3. Toast trigger: show iff the freeze fired *yesterday* and
            //    the user actually has a streak to talk about. Then reset
            //    the flag immediately so it doesn't re-show next launch.
            let defaults = UserDefaults.standard
            let didUseFreeze = defaults.bool(forKey: StreakManager.freezeUsedYesterdayKey)
            if didUseFreeze && streakManager.currentStreak > 0 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    showFreezeToast = true
                }
            }
            // Reset regardless — first-launch users with no streak still
            // need the flag cleared, otherwise it'd fire later.
            if didUseFreeze {
                defaults.set(false, forKey: StreakManager.freezeUsedYesterdayKey)
            }
        }
    }
}

// MARK: - UserDefaults keys

/// 인앱 설문/마이그레이션 관련 UserDefaults 키 모음.
/// 이전에는 `OneTimeMigration` enum 안에 있었으나 마이그레이션 로직이 사라져서
/// 단순 키 컨테이너로 축소. SessionCompleteView가 surveyShownKey를 읽음.
enum OneTimeMigration {
    /// 앱 버전 추적 키. 미래 마이그레이션 시 사용 가능.
    static let installedVersionKey = "installedAppVersion"

    /// 설문 1회 노출 제어. SessionCompleteView가 set/read.
    /// 정책: 모든 사용자(신규 + 기존)가 다음 마스터리에서 설문 1회 노출.
    static let surveyShownKey = "surveyShown"
}
