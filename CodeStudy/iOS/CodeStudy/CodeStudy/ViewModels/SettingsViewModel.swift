import Foundation
import SwiftData
import UserNotifications

@MainActor
@Observable
final class SettingsViewModel {

    // MARK: - State

    struct State {
        var swiftLevel: SwiftLevel = .beginner
        var language: AppLanguage = .korean
        var notificationEnabled = false
        var reminderHour = 20
        var reminderMinute = 0
        var isLoaded = false
    }

    // MARK: - Actions

    enum Action {
        case loadSettings
        case updateLevel(SwiftLevel)
        case updateLanguage(AppLanguage)
        case toggleNotifications(Bool)
        case updateReminderTime(hour: Int, minute: Int)
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
        case .loadSettings:
            await loadSettings()
        case .updateLevel(let level):
            await updateLevel(level)
        case .updateLanguage(let language):
            await updateLanguage(language)
        case .toggleNotifications(let enabled):
            await toggleNotifications(enabled)
        case .updateReminderTime(let hour, let minute):
            await updateReminderTime(hour: hour, minute: minute)
        }
    }

    // MARK: - Private

    private func loadSettings() async {
        guard let profile = fetchProfile() else { return }

        state.swiftLevel = profile.level
        state.language = profile.language

        // Check current notification authorization status
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        state.notificationEnabled = settings.authorizationStatus == .authorized

        // Load pending reminder to get current time
        let pending = await center.pendingNotificationRequests()
        if let reminder = pending.first(where: { $0.identifier == "daily-study-reminder" }),
           let trigger = reminder.trigger as? UNCalendarNotificationTrigger,
           let hour = trigger.dateComponents.hour,
           let minute = trigger.dateComponents.minute {
            state.reminderHour = hour
            state.reminderMinute = minute
        }

        state.isLoaded = true
    }

    private func updateLevel(_ level: SwiftLevel) async {
        guard let profile = fetchProfile() else { return }
        profile.level = level
        state.swiftLevel = level
        saveContext()
    }

    private func updateLanguage(_ language: AppLanguage) async {
        guard let profile = fetchProfile() else { return }
        profile.language = language
        state.language = language
        saveContext()
    }

    private func toggleNotifications(_ enabled: Bool) async {
        if enabled {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                state.notificationEnabled = granted
                if granted {
                    await scheduleReminder()
                }
            } catch {
                state.notificationEnabled = false
            }
        } else {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            state.notificationEnabled = false
        }
    }

    private func updateReminderTime(hour: Int, minute: Int) async {
        state.reminderHour = hour
        state.reminderMinute = minute

        if state.notificationEnabled {
            await scheduleReminder()
        }
    }

    private func scheduleReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-study-reminder"])

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

    // MARK: - Helpers

    private func fetchProfile() -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        return try? modelContext.fetch(descriptor).first
    }

    private func saveContext() {
        try? modelContext.save()
    }
}
