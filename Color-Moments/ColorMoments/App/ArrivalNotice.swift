import Foundation
import UserNotifications

/// 사진 있던 날, 일찍 닫지도 받지도 않았으면 다음 날 아침 8시에 한 번. 할 일을 주는 저녁 재촉이 아니라
/// 선물이 도착했다는 소식 — 앱을 열기만 하면 증정은 DayGiftPresenter 가 알아서 띄운다.
enum ArrivalNotice {

    struct Request: Equatable {
        let id: String
        let fireDate: Date
        let body: String
    }

    static let idPrefix = "arrival-"

    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .autoupdatingCurrent
        return cal
    }()

    /// 사진이 담길 때·앱 active/background 전환 때 부른다 — 조건이 맞으면 오늘 dayKey 에 대해
    /// 내일 08시 요청을 (다시) 걸고, 안 맞으면 지운다. 지금 요청 말고 남은 arrival-* 는 지난 날
    /// 식별자이므로 함께 정리한다. 권한이 없으면 아무것도 안 한다.
    @MainActor
    static func sync(store: DayStore, closures: DayClosures, gifts: GiftLog) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            await removeOthers(center: center, keeping: nil)
            return
        }

        let todayKey = Moment.dayKey(for: Date())
        let request = plan(dayKey: todayKey,
                           hasPebble: store.hasSealedMoments(on: todayKey),
                           closed: closures.closedAt(todayKey) != nil,
                           gifted: gifts.isGifted(todayKey),
                           pebbleName: PebbleNaming.name(for: store.pebbleMoments(on: todayKey))?.name,
                           now: Date(), calendar: calendar)

        await removeOthers(center: center, keeping: request?.id)
        guard let request else { return }

        let content = UNMutableNotificationContent()
        content.title = "몽돌"
        content.body = request.body
        content.sound = .default

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: request.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
    }

    /// 그 날짜 알림만 지운다 — 증정 장면이 끝난 직후(markGifted 뒤) 불러서, 4~8시 사이에 이미
    /// 받았으면 8시 알림이 뒤늦게 오지 않게 한다.
    @MainActor
    static func clear(dayKey: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [idPrefix + dayKey])
    }

    private static func removeOthers(center: UNUserNotificationCenter, keeping id: String?) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        let stale = pending.filter { $0 != id }
        guard !stale.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: stale)
    }

    /// 순수 판정 — 사진이 없거나 닫았거나 이미 받았으면 nil. 발화 시각은 dayKey 다음 날 08시,
    /// 이미 지났으면 nil.
    static func plan(dayKey: String, hasPebble: Bool, closed: Bool, gifted: Bool,
                     pebbleName: String?, now: Date, calendar: Calendar) -> Request? {
        guard hasPebble, !closed, !gifted else { return nil }
        guard let fireDate = arrivalDate(for: dayKey, calendar: calendar), now < fireDate else { return nil }
        return Request(id: idPrefix + dayKey, fireDate: fireDate, body: body(for: pebbleName))
    }

    // dayKey 의 달력 날짜 다음 날 08시.
    private static func arrivalDate(for dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]; c.month = parts[1]; c.day = parts[2]
        c.hour = 8; c.minute = 0; c.second = 0
        guard let sameDayEight = calendar.date(from: c) else { return nil }
        return calendar.date(byAdding: .day, value: 1, to: sameDayEight)
    }

    private static func body(for pebbleName: String?) -> String {
        guard let pebbleName, !pebbleName.isEmpty else { return "어제의 조약돌이 도착했어요." }
        return "어제의 조약돌, 〈\(pebbleName)〉\(particle(for: pebbleName)) 도착했어요."
    }

    // 마지막 글자에 받침이 있으면 "이", 없으면 "가". 한글 음절이 아니면 "가"로 둔다.
    private static func particle(for name: String) -> String {
        guard let last = name.unicodeScalars.last, (0xAC00...0xD7A3).contains(last.value) else { return "가" }
        let jongseong = (last.value - 0xAC00) % 28
        return jongseong == 0 ? "가" : "이"
    }
}
