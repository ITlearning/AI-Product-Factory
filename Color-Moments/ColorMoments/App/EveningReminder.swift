import Foundation
import UserNotifications

/// 오늘 사진이 있고 아직 마무리 안 했으면 밤 10시에 한 번만 알린다. 서버 없음, 로컬 알림뿐.
enum EveningReminder {

    struct Request: Equatable {
        let id: String
        let fireDate: Date
        let body: String
    }

    static let idPrefix = "evening-"

    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .autoupdatingCurrent
        return cal
    }()

    /// 사진이 담길 때·마무리할 때·앱 active/background 전환 때 부른다 — 조건이 맞으면 오늘 22시 요청을
    /// (다시) 걸고, 안 맞으면 대기 중인 evening-* 를 전부 지운다. 권한이 없으면 아무것도 안 한다.
    @MainActor
    static func sync(store: DayStore, closures: DayClosures) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            await clearPending(center: center)
            return
        }

        let todayKey = Moment.dayKey(for: Date())
        let request = plan(todayKey: todayKey,
                           momentCount: store.moments(on: todayKey).count,
                           closed: closures.closedAt(todayKey) != nil,
                           now: Date(), calendar: calendar)
        guard let request else {
            await clearPending(center: center)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "몽돌"
        content.body = request.body
        content.sound = .default
        content.userInfo = ["dayKey": todayKey]

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: request.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
    }

    private static func clearPending(center: UNUserNotificationCenter) async {
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// 순수 판정 — 사진이 없거나 이미 마무리했거나 오늘 22시가 지났으면 nil.
    static func plan(todayKey: String, momentCount: Int, closed: Bool, now: Date, calendar: Calendar) -> Request? {
        guard momentCount > 0, !closed else { return nil }
        guard let fireDate = eveningDate(for: todayKey, calendar: calendar), now < fireDate else { return nil }
        return Request(id: idPrefix + todayKey, fireDate: fireDate, body: body(for: momentCount))
    }

    // dayKey 의 달력 날짜 22시 — 4시 경계라 dayKey 날짜와 같은 날 밤이다.
    private static func eveningDate(for dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]; c.month = parts[1]; c.day = parts[2]
        c.hour = 22; c.minute = 0; c.second = 0
        return calendar.date(from: c)
    }

    private static func body(for count: Int) -> String {
        "오늘 \(countText(count)) 순간이 담겼어요. 지금 조약돌로 열어 볼 수 있어요."
    }

    private static let counters = ["한", "두", "세", "네", "다섯", "여섯", "일곱", "여덟", "아홉", "열"]

    private static func countText(_ n: Int) -> String {
        guard n >= 1, n <= counters.count else { return "\(n)개의" }
        return counters[n - 1]
    }
}
