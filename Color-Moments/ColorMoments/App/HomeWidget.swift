import WidgetKit

enum HomeWidget {

    @MainActor
    static func refresh(store: DayStore, gifts: GiftLog) {
        WidgetSnapshot.make(store: store, gifts: gifts).write()
        WidgetCenter.shared.reloadAllTimelines()
    }

    @MainActor
    static func syncWithArrivalNotice(store: DayStore, closures: DayClosures, gifts: GiftLog) async {
        refresh(store: store, gifts: gifts)
        await ArrivalNotice.sync(store: store, closures: closures, gifts: gifts)
    }
}
