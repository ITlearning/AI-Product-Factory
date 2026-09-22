import SwiftUI

public extension View {
    /// 아직 안 건넨 하루가 있으면 증정 장면을 띄운다.
    ///
    /// 화면 하나에 묶어두지 않고 수식어로 뺀 이유: 증정은 «어느 화면에 있든 하루에 한 번»이라
    /// 홈이 바뀌어도 따라다녀야 하고, **두 화면이 각자 띄우면 두 번 뜬다.** 붙이는 자리는 하나다.
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
            // 자정을 넘겨 돌아온 경우. 앱을 껐다 켜지 않아도 그날이 건네진다.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { present() }
            }
            .fullScreenCover(item: $pending) { day in
                BadgeCeremony(
                    moments: store.moments(on: day.id),
                    // **사용자가 실제로 닫았을 때만 이력에 남긴다.**
                    // `.onDisappear` 는 앱이 내려갈 때도 불려서, 보지도 않은 하루가
                    // «증정 완료»로 기록된다(실기기에서 잡음).
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
                                             today: Moment.dayKey(for: Date())) else { return }
        pending = PendingDay(id: key)
    }
}
