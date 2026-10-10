import SwiftUI

public extension View {

    /// dismissedTick — 하루 상세 시트가 완전히 닫힐 때마다(onDismiss) 호출부가 올리는 값.
    /// blocksPresentation — 하루 상세·사진첩 선택 등 다른 fullScreenCover/sheet 가 떠 있는 동안 true.
    /// 여는 순간 true, 그 시트·커버의 onDismiss 에서만 false 로 바꿔야 한다.
    /// 이 동안은 present() 를 미룬다 — 동시에 두 개를 띄우면 나중 것의 표시가 씹혀 pending 이 안 풀린다.
    // onboardingGiftDay — 첫 담기로 고른 하루(있으면 hasSealedMoments 없이 한 번 증정). 지우는 건 호출부 몫.
    // onCeremonyFinished — 증정 커버가 완전히 닫힌 뒤(onDismiss) 그 날짜로 한 번 불린다.
    func dayGift(store: DayStore, gifts: GiftLog, dismissedTick: Int, blocksPresentation: Bool,
                 onboardingGiftDay: String? = nil,
                 onCeremonyFinished: ((String) -> Void)? = nil) -> some View {
        modifier(DayGiftPresenter(store: store, gifts: gifts, dismissedTick: dismissedTick,
                                  blocksPresentation: blocksPresentation, onboardingGiftDay: onboardingGiftDay,
                                  onCeremonyFinished: onCeremonyFinished))
    }
}

struct DayGiftPresenter: ViewModifier {
    let store: DayStore
    let gifts: GiftLog
    let dismissedTick: Int
    let blocksPresentation: Bool
    let onboardingGiftDay: String?
    let onCeremonyFinished: ((String) -> Void)?

    @Environment(\.scenePhase) private var scenePhase
    @State private var pending: PendingDay?
    // pending 은 닫힘 애니메이션 시작에 nil 이 된다 — 커버가 다 닫히기 전 다음 증정을 막는다.
    @State private var ceremonyUp = false
    // pending 이 nil 로 바뀐 뒤에도 onDismiss 에 어느 날이었는지 알려주려고 따로 들고 있는다.
    @State private var lastShownDayKey: String?

    private struct PendingDay: Identifiable { let id: String }

    func body(content: Content) -> some View {
        content
            .task { present() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { present() }
            }
            // 호출부는 두 값을 시트·커버의 onDismiss(닫힘 애니메이션이 끝난 뒤)에서만 바꾼다 — 닫히는 도중에
            // 조상의 fullScreenCover 를 띄우면 표시가 씹혀 pending 이 영영 안 풀린다.
            .onChange(of: dismissedTick) { _, _ in present() }
            .onChange(of: store.isLoaded) { _, loaded in if loaded { present() } }
            .onChange(of: blocksPresentation) { _, blocked in
                if !blocked { present() }
            }
            // 어제를 막 증정했으면 마무리한 오늘이 다음 트리거까지 기다리지 않고 커버가 다 닫힌 뒤 이어서 뜬다.
            .fullScreenCover(item: $pending, onDismiss: {
                ceremonyUp = false
                if let key = Self.finishedDay(lastShown: lastShownDayKey, isGifted: gifts.isGifted) { onCeremonyFinished?(key) }
                present()
            }) { day in
                BadgeCeremony(
                    moments: store.pebbleMoments(on: day.id),
                    isPresented: Binding(get: { pending != nil },
                                         set: { shown in
                                             guard !shown else { return }
                                             PebbleNaming.stamp(day.id, moments: store.pebbleMoments(on: day.id))
                                             DayGradient.stamps.stampOnGift(day.id, moments: store.pebbleMoments(on: day.id))
                                             gifts.markGifted(day.id)
                                             pending = nil
                                         }))
            }
    }

    /// 카메라 요청이 증정을 받기 전에 내렸으면 끝난 게 아니다 — 증정은 다음 기회에 다시 뜬다.
    static func finishedDay(lastShown: String?, isGifted: (String) -> Bool) -> String? {
        lastShown.flatMap { isGifted($0) ? $0 : nil }
    }

    private func present() {
        guard store.isLoaded, pending == nil, !ceremonyUp, !blocksPresentation else { return }
        guard let key = GiftSchedule.pendingWithOnboarding(onboardingGiftDay: onboardingGiftDay,
                                             isGifted: gifts.isGifted,
                                             dayKeys: store.dayKeys,
                                             today: Moment.dayKey(for: Date()),
                                             hasSealedMoments: store.hasSealedMoments,
                                             isFinished: store.isFinished) else { return }
        ceremonyUp = true
        pending = PendingDay(id: key)
        lastShownDayKey = key
    }
}
