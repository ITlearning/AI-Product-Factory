import WidgetKit

enum HomeWidget {

    @MainActor
    static func refresh(store: DayStore, gifts: GiftLog) {
        WidgetSnapshot.make(store: store, gifts: gifts).write()
        WidgetCenter.shared.reloadAllTimelines()
    }

    @MainActor private static var scheduled: Task<Void, Never>?
    @MainActor private static var hold: CoalescingWriter.Release?

    /// iCloud 로 묶음이 잇달아 들어올 때 — 마지막 묶음 뒤 한 번만 위젯·알림을 맞춘다(reloadAllTimelines 는 예산이 있다).
    @MainActor
    static func scheduleSync(store: DayStore, closures: DayClosures, gifts: GiftLog) {
        scheduled?.cancel()
        // 백그라운드 푸시로 받았으면 기다리는 700ms 사이에 멈춰 위젯·알림이 안 맞춰진다 — 끝날 때까지 붙잡는다.
        if hold == nil { hold = BackgroundHold.begin("mongdol.widgetSync") }
        scheduled = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            // 돌기 시작한 동기화는 취소하지 않는다 — 알림 등록 도중 끊기면 예약이 반쯤만 남는다.
            scheduled = nil
            await syncWithArrivalNotice(store: store, closures: closures, gifts: gifts)
            if scheduled == nil {
                hold?()
                hold = nil
            }
        }
    }

    @MainActor
    static func syncWithArrivalNotice(store: DayStore, closures: DayClosures, gifts: GiftLog) async {
        refresh(store: store, gifts: gifts)
        await ArrivalNotice.sync(store: store, closures: closures, gifts: gifts)
        if !store.today.isEmpty { MomentReminder.clearToday() }
        await MomentReminder.sync(store: store)
    }
}
