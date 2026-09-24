import WidgetKit

enum HomeWidget {

    @MainActor
    static func refresh(store: DayStore, gifts: GiftLog) {
        WidgetSnapshot.make(store: store, gifts: gifts).write()
        WidgetCenter.shared.reloadAllTimelines()
    }

    @MainActor private static var scheduled: Task<Void, Never>?

    /// iCloud 로 묶음이 잇달아 들어올 때 — 마지막 묶음 뒤 한 번만 위젯·알림을 맞춘다(reloadAllTimelines 는 예산이 있다).
    @MainActor
    static func scheduleSync(store: DayStore, closures: DayClosures, gifts: GiftLog) {
        scheduled?.cancel()
        scheduled = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            // 돌기 시작한 동기화는 취소하지 않는다 — 알림 등록 도중 끊기면 예약이 반쯤만 남는다.
            scheduled = nil
            await syncWithArrivalNotice(store: store, closures: closures, gifts: gifts)
        }
    }

    @MainActor
    static func syncWithArrivalNotice(store: DayStore, closures: DayClosures, gifts: GiftLog) async {
        refresh(store: store, gifts: gifts)
        await ArrivalNotice.sync(store: store, closures: closures, gifts: gifts)
    }
}
