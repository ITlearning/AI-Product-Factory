import SwiftUI

/// 새 사용자 첫 실행 — 한 화면에 한 가지, 옆으로 넘긴다. 무거운 준비는 넘기는 동안 뒤에서 돈다.
struct OnboardingView: View {
    let store: DayStore
    let gifts: GiftLog
    let closures: DayClosures
    let prepare: () async -> Void
    let onFinish: (_ openCamera: Bool) -> Void

    @AppStorage("onboardingGiftDay") private var onboardingGiftDay: String?
    @AppStorage("didAskArrivalNotice") private var didAskArrivalNotice = false

    @State private var index = 0
    @State private var forward = true
    // 도중에 답하면 단계가 빠져 번호가 밀린다 — 처음 본 값으로 고정한다.
    @State private var asksArrival = !UserDefaults.standard.bool(forKey: "didAskArrivalNotice")
    @State private var continuing: Bool?
    @State private var skipsFirstPebble = false
    @State private var importedDayKeys: Set<String> = []
    @State private var firstPebble = FirstPebbleModel()
    @State private var ceremonyDay: CeremonyDay?
    @State private var pickingLibrary = false
    @State private var pickerOutcome: OnboardingFlow.ImportOutcome?
    @State private var working = 0
    @State private var waitedLongEnough = false

    private struct CeremonyDay: Identifiable { let id: String }

    private var steps: [OnboardingStep] {
        OnboardingFlow.steps(continuing: continuing ?? false, skipsFirstPebble: skipsFirstPebble,
                             asksArrival: asksArrival)
    }

    private var step: OnboardingStep { steps[min(index, steps.count - 1)] }

    private var remoteDays: Int {
        OnboardingFlow.remoteDayCount(dayKeys: store.dayKeys, importedDayKeys: importedDayKeys)
    }

    private var ready: Bool { working == 0 || waitedLongEnough }

    var body: some View {
        ZStack {
            Tone.base.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ZStack {
                    page(step)
                        .id(step)
                        .transition(.asymmetric(
                            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
            if v.translation.width < -60, canSwipeForward { next() }
            if v.translation.width > 60 { back() }
        })
        .task { track { await prepare() } }
        .fullScreenCover(item: $ceremonyDay, onDismiss: ceremonyFinished) { day in
            BadgeCeremony(moments: store.pebbleMoments(on: day.id),
                          isPresented: Binding(get: { ceremonyDay != nil },
                                               set: { shown in
                                                   guard !shown else { return }
                                                   gifts.markGifted(day.id)
                                                   ceremonyDay = nil
                                               }))
        }
        .fullScreenCover(isPresented: $pickingLibrary, onDismiss: {
            // 사진첩 커버가 다 닫힌 뒤에야 증정 커버를 띄울 수 있다 — 겹치면 표시가 씹힌다.
            if let outcome = pickerOutcome { pickerOutcome = nil; handle(outcome) }
        }) {
            LibraryPickerView(store: store) { keys in
                importedDayKeys.formUnion(keys)
                guard !keys.isEmpty else { return }
                pickerOutcome = OnboardingFlow.outcome(existingRecordsWereEmpty: pickerStartedEmpty,
                                                      importedDayKeys: keys, today: Moment.dayKey(for: Date()))
                afterImport()
            }
        }
        .onDisappear { firstPebble.stop() }
    }

    @State private var pickerStartedEmpty = true

    // MARK: 틀

    private var topBar: some View {
        ZStack {
            HStack(spacing: 7) {
                ForEach(steps.indices, id: \.self) { i in
                    Circle()
                        .fill(i == index ? Tone.primary : Tone.hairline)
                        .frame(width: 6, height: 6)
                }
            }
            .animation(.easeOut(duration: 0.2), value: index)
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(Face.lineCeremony)
                        .foregroundStyle(Tone.secondary)
                        .frame(width: Shape2.minTouch, height: Shape2.minTouch)
                }
                .opacity(canGoBack ? 1 : 0)
                .disabled(!canGoBack)
                Spacer()
            }
            .padding(.leading, 12)
        }
        .frame(height: 52)
    }

    private var busy: Bool { firstPebble.phase == .importing || ceremonyDay != nil || pickingLibrary }

    private var canGoBack: Bool { index > 0 && !busy }

    private var canSwipeForward: Bool {
        switch step {
        case .arrival: didAskArrivalNotice
        case .start: false
        case .firstPebble: !busy
        default: true
        }
    }

    private func next() {
        if step == .intro, continuing == nil {
            #if DEBUG
            // 디버그 「온보딩 다시 보기」는 기록이 있어도 첫 조약돌 단계를 보여 준다.
            let replay = UserDefaults.standard.bool(forKey: "debugReplayOnboarding")
            #else
            let replay = false
            #endif
            continuing = !replay && remoteDays > 0
        }
        guard index < steps.count - 1 else { return }
        forward = true
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) { index += 1 }
    }

    private func back() {
        guard canGoBack else { return }
        forward = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) { index -= 1 }
    }

    private func track(_ work: @escaping () async -> Void) {
        working += 1
        Task { @MainActor in
            await work()
            working -= 1
        }
    }

    // MARK: 단계

    @ViewBuilder
    private func page(_ step: OnboardingStep) -> some View {
        switch step {
        case .intro:
            IntroStep(next: next)
        case .firstPebble:
            FirstPebbleStep(model: firstPebble, store: store,
                            begin: beginFirstPebble,
                            receive: receiveSelected,
                            pickManually: {
                                pickerStartedEmpty = store.moments.isEmpty
                                pickingLibrary = true
                            },
                            next: next)
        case .continuing:
            CloudStep(remoteDays: remoteDays, dayCount: store.dayKeys.count, actionTitle: "이어서 보기", next: next)
        case .cloud:
            CloudStep(remoteDays: remoteDays, dayCount: store.dayKeys.count, actionTitle: "다음", next: next)
        case .arrival:
            ArrivalStep(store: store, closures: closures, gifts: gifts, answered: next)
        case .howTo:
            HowToStep(next: next)
        case .start:
            StartStep(ready: ready,
                      onCamera: { onFinish(true) },
                      onStart: { onFinish(false) })
                .task {
                    // 준비가 오래 걸려도 여기서 붙잡아 두지 않는다 — 남은 일은 홈에서도 뒤에서 이어진다.
                    try? await Task.sleep(for: .seconds(4))
                    waitedLongEnough = true
                }
        }
    }

    private func beginFirstPebble(_ ask: Bool) async {
        guard await firstPebble.begin(askIfNeeded: ask) else {
            withAnimation(.easeInOut(duration: 0.35)) { skipsFirstPebble = true }
            return
        }
    }

    private func receiveSelected() async {
        let (outcome, keys) = await firstPebble.importSelected(store: store)
        importedDayKeys.formUnion(keys)
        guard outcome != .nothing else { return }
        afterImport()
        handle(outcome)
    }

    private func afterImport() {
        track { await HomeWidget.syncWithArrivalNotice(store: store, closures: closures, gifts: gifts) }
        track { await prepare() }
    }

    private func handle(_ outcome: OnboardingFlow.ImportOutcome) {
        firstPebble.received(outcome)
        guard case .gift(let day) = outcome else { return }
        // 온보딩 도중 앱이 닫혀도 홈의 증정이 이 하루를 이어받는다.
        onboardingGiftDay = day
        ceremonyDay = CeremonyDay(id: day)
    }

    private func ceremonyFinished() {
        if let day = onboardingGiftDay, gifts.isGifted(day) {
            onboardingGiftDay = nil
            Task { await ArrivalNotice.clear(dayKey: day) }
        }
        HomeWidget.refresh(store: store, gifts: gifts)
        next()
    }
}
