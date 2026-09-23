import SwiftUI

public extension View {

    /// dismissedTick — 하루 상세 시트가 닫힐 때마다 호출부가 올리는 값. 시트가 완전히
    /// 닫힌 뒤에만 증정을 시도하려고 자정 타이머 대신 이 값의 변화를 신호로 쓴다.
    func dayGift(store: DayStore, gifts: GiftLog, closures: DayClosures, dismissedTick: Int) -> some View {
        modifier(DayGiftPresenter(store: store, gifts: gifts, closures: closures, dismissedTick: dismissedTick))
    }
}

struct DayGiftPresenter: ViewModifier {
    let store: DayStore
    let gifts: GiftLog
    let closures: DayClosures
    let dismissedTick: Int

    @Environment(\.scenePhase) private var scenePhase
    @State private var pending: PendingDay?

    private struct PendingDay: Identifiable { let id: String }

    func body(content: Content) -> some View {
        content
            .task { present() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { present() }
            }
            // 하루 상세 시트가 완전히 닫힌 뒤에만 증정을 시도한다 — 시트가 dismiss 되는
            // 도중에 조상의 fullScreenCover 를 띄우면 표시가 씹혀 pending 이 영영 안 풀린다.
            .onChange(of: dismissedTick) { _, _ in presentAfterDismiss() }
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

    private func presentAfterDismiss() {
        Task { @MainActor in
            // 시트 dismiss 애니메이션이 실제로 끝나도록 한 틱 미룬다.
            try? await Task.sleep(nanoseconds: 50_000_000)
            present()
        }
    }

    private func present() {
        guard pending == nil else { return }
        guard let key = GiftSchedule.pending(dayKeys: store.dayKeys,
                                             today: Moment.dayKey(for: Date()),
                                             isGifted: gifts.isGifted,
                                             hasSealedMoments: store.hasSealedMoments,
                                             isFinished: store.isFinished) else { return }
        pending = PendingDay(id: key)
    }
}
