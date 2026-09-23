import SwiftUI

public extension View {

    func dayGift(store: DayStore, gifts: GiftLog) -> some View {
        modifier(DayGiftPresenter(store: store, gifts: gifts))
    }
}

struct DayGiftPresenter: ViewModifier {
    let store: DayStore
    let gifts: GiftLog

    @Environment(\.scenePhase) private var scenePhase
    @State private var pending: PendingDay?

    private struct PendingDay: Identifiable { let id: String }

    func body(content: Content) -> some View {
        content
            .task { present() }

            .onChange(of: scenePhase) { _, phase in
                if phase == .active { present() }
            }
            .fullScreenCover(item: $pending) { day in
                BadgeCeremony(
                    moments: store.pebbleMoments(on: day.id),

                    isPresented: Binding(get: { pending != nil },
                                         set: { shown in
                                             guard !shown else { return }
                                             gifts.markGifted(day.id)
                                             pending = nil
                                         }))
            }
    }

    private func present() {
        guard pending == nil else { return }
        guard let key = GiftSchedule.pending(dayKeys: store.dayKeys,
                                             lastGifted: gifts.lastGiftedDayKey,
                                             today: Moment.dayKey(for: Date()),
                                             hasSealedMoments: store.hasSealedMoments) else { return }
        pending = PendingDay(id: key)
    }
}
