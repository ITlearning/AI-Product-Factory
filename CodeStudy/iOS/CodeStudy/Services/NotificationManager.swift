import Foundation
import UserNotifications

// MARK: - NotificationManager

final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let dailyReminderID = "daily-study-reminder"

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Daily Reminder

    func scheduleDailyReminder(hour: Int, minute: Int, conceptTip: String?) {
        // Remove existing reminder before scheduling new one
        cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "notification.reminder.title",
            defaultValue: "오늘의 Swift 학습"
        )

        if let tip = conceptTip, !tip.isEmpty {
            content.body = String(
                localized: "notification.reminder.bodyWithTip \(tip)",
                defaultValue: "💡 \(tip)"
            )
        } else {
            content.body = String(
                localized: "notification.reminder.body",
                defaultValue: "오늘도 Swift 한 개념 마스터해볼까요?"
            )
        }

        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: dailyReminderID,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
    }
}
