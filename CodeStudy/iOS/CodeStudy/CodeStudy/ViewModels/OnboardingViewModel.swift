import Foundation
import SwiftData
import UserNotifications

@MainActor
@Observable
final class OnboardingViewModel {

    // MARK: - State

    struct State {
        var currentStep: OnboardingStep = .experience
        var hasDevelopmentExperience: Bool?
        var swiftLevel: SwiftLevel?
        var notificationEnabled = false
        var reminderHour = 20   // default 8 PM
        var reminderMinute = 0
        var isComplete = false
    }

    enum OnboardingStep: Int, CaseIterable {
        case experience = 0
        case swiftLevel = 1
        case notification = 2
    }

    // MARK: - Actions

    enum Action {
        case setExperience(Bool)
        case setSwiftLevel(SwiftLevel)
        case enableNotifications
        case skipNotifications
        case setReminderTime(hour: Int, minute: Int)
        case completeOnboarding
    }

    // MARK: - Published State

    var state = State()

    // MARK: - Dependencies

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Action Handler

    func handle(_ action: Action) async {
        switch action {
        case .setExperience(let hasExperience):
            state.hasDevelopmentExperience = hasExperience
            advanceStep()

        case .setSwiftLevel(let level):
            state.swiftLevel = level
            advanceStep()

        case .enableNotifications:
            await requestNotificationPermission()
            state.notificationEnabled = true

        case .skipNotifications:
            state.notificationEnabled = false
            // Don't advance — user will tap "Complete" after choosing skip

        case .setReminderTime(let hour, let minute):
            state.reminderHour = hour
            state.reminderMinute = minute

        case .completeOnboarding:
            await completeOnboarding()
        }
    }

    // MARK: - Navigation

    var canAdvance: Bool {
        switch state.currentStep {
        case .experience:
            return state.hasDevelopmentExperience != nil
        case .swiftLevel:
            return state.swiftLevel != nil
        case .notification:
            return true  // always can finish
        }
    }

    var progress: Double {
        Double(state.currentStep.rawValue + 1) / Double(OnboardingStep.allCases.count)
    }

    // MARK: - Private

    private func advanceStep() {
        guard let nextRaw = OnboardingStep(rawValue: state.currentStep.rawValue + 1) else {
            return
        }
        state.currentStep = nextRaw
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await scheduleReminder()
            }
        } catch {
            // Permission denied — treat as "skipped"
            state.notificationEnabled = false
        }
    }

    private func scheduleReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.reminder.title", defaultValue: "오늘의 Swift 학습")
        content.body = String(localized: "notification.reminder.body", defaultValue: "5분만 투자해서 새로운 개념을 마스터해보세요!")
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = state.reminderHour
        dateComponents.minute = state.reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-study-reminder",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    private func completeOnboarding() async {
        let experience = state.hasDevelopmentExperience ?? false
        let level = state.swiftLevel ?? .beginner

        // 신규 사용자는 디바이스 locale 따라감. 영어권 디바이스 = .english.
        // 사용자가 Settings에서 언제든 변경 가능.
        let profile = UserProfile(
            hasDevelopmentExperience: experience,
            swiftLevel: level,
            preferredLanguage: .systemDefault
        )

        modelContext.insert(profile)

        do {
            try modelContext.save()
            state.isComplete = true
        } catch {
            // SwiftData save failure — in production, show alert
        }

        // Schedule notification if enabled
        if state.notificationEnabled {
            await scheduleReminder()
        }
    }
}
