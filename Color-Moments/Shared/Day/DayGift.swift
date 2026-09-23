import SwiftUI

public extension View {

    func dayGift(store: DayStore, gifts: GiftLog, closures: DayClosures) -> some View {
        modifier(DayGiftPresenter(store: store, gifts: gifts, closures: closures))
    }
}

struct DayGiftPresenter: ViewModifier {
    let store: DayStore
    let gifts: GiftLog
    let closures: DayClosures

    @Environment(\.scenePhase) private var scenePhase
    @State private var pending: PendingDay?

    private struct PendingDay: Identifiable { let id: String }

    func body(content: Content) -> some View {
        content
            .task { present() }

            .onChange(of: scenePhase) { _, phase in
                if phase == .active { present() }
            }
            // 「오늘 마무리하기」로 방금 닫혔으면 자정을 기다리지 않고 바로 증정 장면을 띄운다.
            .onChange(of: closures.closedAt(Moment.dayKey(for: Date()))) { _, _ in present() }
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
                                             hasSealedMoments: store.hasSealedMoments,
                                             isFinished: store.isFinished) else { return }
        pending = PendingDay(id: key)
    }
}
