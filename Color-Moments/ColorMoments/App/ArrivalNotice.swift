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
    // 조약돌 이름은 색으로 정해진다 — 색은 증정에서 처음 열려야 하므로 본문에 이름을 넣지 않는다.
    static let body = "어제의 조약돌이 도착했어요."

    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .autoupdatingCurrent
        return cal
    }()

    @MainActor private static var syncing = false
    @MainActor private static var syncAgain = false

    /// 사진이 담길 때·앱 active/background 전환 때 부른다 — targets 의 날짜마다 조건이 맞으면
    /// 다음 날 08시 요청을 (다시) 걸고, 그 밖의 arrival-* (지난 날·조건이 깨진 날)는 예약·전달 모두 지운다.
    /// 권한이 없으면 모두 지우기만 한다. 돌던 중 들어온 요청은 끝난 뒤 한 번 더 돈다.
    @MainActor
    static func sync(store: DayStore, closures: DayClosures, gifts: GiftLog) async {
        guard !syncing else { syncAgain = true; return }
        syncing = true
        defer { syncing = false }
        repeat {
            syncAgain = false
            await syncOnce(store: store, closures: closures, gifts: gifts)
        } while syncAgain
    }

    @MainActor
    private static func syncOnce(store: DayStore, closures: DayClosures, gifts: GiftLog) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            await removeOthers(center: center, keeping: [])
            return
        }

        let requests = requests(store: store, closures: closures, gifts: gifts, now: Date())
        await removeOthers(center: center, keeping: Set(requests.map(\.id)))

        for request in requests {
            // await 사이에 증정·닫힘이 끝났을 수 있다 — add 직전에 다시 판정한다.
            guard Self.requests(store: store, closures: closures, gifts: gifts, now: Date())
                .contains(where: { $0.id == request.id }) else { continue }
            let content = UNMutableNotificationContent()
            content.title = "몽돌"
            content.body = request.body
            content.sound = .default

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: request.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
        }
    }

    @MainActor
    private static func requests(store: DayStore, closures: DayClosures, gifts: GiftLog, now: Date) -> [Request] {
        targets(now: now, calendar: calendar).compactMap { key in
            plan(dayKey: key,
                 hasPebble: store.hasSealedMoments(on: key),
                 closed: closures.closedAt(key) != nil,
                 gifted: gifts.isGifted(key),
                 now: now, calendar: calendar)
        }
    }

    /// 그 날짜 알림만 지운다(예약·전달 모두) — 증정 장면이 끝난 직후(markGifted 뒤) 불러서, 4~8시 사이에
    /// 이미 받았으면 8시 알림이 뒤늦게 오지 않게 하고, 이미 온 소식은 알림 센터에서 걷는다.
    @MainActor
    static func clear(dayKey: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [idPrefix + dayKey])
        center.removeDeliveredNotifications(withIdentifiers: [idPrefix + dayKey])
        if syncing { syncAgain = true }
    }

    /// DEBUG 전체 초기화용 — arrival-* 를 예약·전달 모두 지운다.
    @MainActor
    static func removeAll() async {
        await removeOthers(center: UNUserNotificationCenter.current(), keeping: [])
    }

    private static func removeOthers(center: UNUserNotificationCenter, keeping ids: Set<String>) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(idPrefix) && !ids.contains($0) }
        if !pending.isEmpty { center.removePendingNotificationRequests(withIdentifiers: pending) }
        let delivered = await center.deliveredNotifications().map(\.request.identifier)
            .filter { $0.hasPrefix(idPrefix) && !ids.contains($0) }
        if !delivered.isEmpty { center.removeDeliveredNotifications(withIdentifiers: delivered) }
    }

    /// 첫 증정 뒤 권한을 물을지 — 다음 증정이 이어서 뜰 참이면 커버와 alert 가 겹치므로 그 증정이 끝난 뒤로 미룬다.
    static func shouldAsk(didAsk: Bool, nextGift: String?) -> Bool {
        !didAsk && nextGift == nil
    }

    /// 순수 판정 — sync 가 계획할 dayKey 들. 오늘 dayKey 에 더해, 4~8시 사이엔 어제 dayKey 의 08시도
    /// 아직 안 왔으므로 함께 둔다. 발화 시각(dayKey 다음 날 08시)이 지난 날은 뺀다.
    static func targets(now: Date, calendar: Calendar) -> [String] {
        let today = dayKey(for: now, calendar: calendar)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now).map { dayKey(for: $0, calendar: calendar) }
        return [yesterday, today].compactMap { $0 }.filter { key in
            arrivalDate(for: key, calendar: calendar).map { now < $0 } ?? false
        }
    }

    /// 순수 판정 — 사진이 없거나 닫았거나 이미 받았으면 nil. 발화 시각은 dayKey 다음 날 08시,
    /// 이미 지났으면 nil.
    static func plan(dayKey: String, hasPebble: Bool, closed: Bool, gifted: Bool,
                     now: Date, calendar: Calendar) -> Request? {
        guard hasPebble, !closed, !gifted else { return nil }
        guard let fireDate = arrivalDate(for: dayKey, calendar: calendar), now < fireDate else { return nil }
        return Request(id: idPrefix + dayKey, fireDate: fireDate, body: body)
    }

    // Moment.dayKey(for:) 와 같은 4시 경계 — 테스트가 달력을 주입하려고 따로 둔다.
    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let shifted = calendar.date(byAdding: .hour, value: -Moment.dayBoundaryHour, to: date) ?? date
        let c = calendar.dateComponents([.year, .month, .day], from: shifted)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
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
}
