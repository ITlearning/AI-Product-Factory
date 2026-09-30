import AVFoundation
import Photos
import SwiftUI

/// 온보딩을 마치고 어디로 가나 — 홈, 카메라가 열린 홈, 방금 받은 하루.
enum OnboardingExit: Equatable {
    case home, camera, day(String)
}

/// 새 사용자 첫 실행 — 한 화면에 한 가지, 옆으로 넘긴다. 무거운 준비는 넘기는 동안 뒤에서 돈다.
struct OnboardingView: View {
    let store: DayStore
    let gifts: GiftLog
    let closures: DayClosures
    let prepare: () async -> Void
    let onFinish: (OnboardingExit) -> Void

    @AppStorage("onboardingGiftDay") private var onboardingGiftDay: String?
    @AppStorage("didAskArrivalNotice") private var didAskArrivalNotice = false

    @State private var index = 0
    @State private var forward = true
    // 도중에 답하면 단계가 빠져 번호가 밀린다 — 처음 본 값으로 고정한다.
    @State private var asksArrival = !UserDefaults.standard.bool(forKey: "didAskArrivalNotice")
    /// 위치 권한을 아직 안 정한 기기만 「찍은 곳」 장을 본다 — 렌치로 다시 볼 땐 늘(모양을 봐야 한다).
    @State private var asksPlace: Bool = {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugReplayOnboarding") { return true }
        #endif
        return PlaceFinder.shared.access == .notAsked
    }()
    @State private var placeAnswered = false
    @State private var continuing: Bool?
    @State private var skipsFirstPebble = false
    @State private var importedDayKeys: Set<String> = []
    /// 이번 온보딩에서 증정까지 받은 하루 — 마지막 장이 「내 조약돌 보러 가기」로 바뀐다.
    @State private var receivedDay: String?
    @State private var firstPebble = FirstPebbleModel()
    @State private var ceremonyDay: CeremonyDay?
    @State private var pickingLibrary = false
    @State private var pickerOutcome: OnboardingFlow.ImportOutcome?
    @State private var working = 0
    @State private var waitedLongEnough = false

    private struct CeremonyDay: Identifiable { let id: String }

    /// iPhone 16 이후(16e 제외)의 옆면 카메라 컨트롤 — 기종 목록 대신 캡처 컨트롤 지원 여부로 가른다.
    private static let hasCameraButton = AVCaptureSession().supportsControls

    private var steps: [OnboardingStep] {
        OnboardingFlow.steps(continuing: continuing ?? false, skipsFirstPebble: skipsFirstPebble,
                             asksArrival: asksArrival, hasCameraButton: Self.hasCameraButton, asksPlace: asksPlace)
    }

    private var step: OnboardingStep { steps[min(index, steps.count - 1)] }

    private var remoteDays: Int {
        OnboardingFlow.remoteDayCount(dayKeys: store.dayKeys, importedDayKeys: importedDayKeys)
    }

    // 마지막 「준비됐어요」만 밝게 — 안내는 어둡게 두고 끝에서 번지듯 밝아진다.
    private var light: Bool { step == .start }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ready: Bool { working == 0 || waitedLongEnough }

    var body: some View {
        ZStack {
            SceneBackdrop(hexes: BackdropPalette.sourceHexes(store: store, gifts: gifts), light: light)
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
        .environment(\.onboardingInk, light ? .light : .dark)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.0), value: light)
        .environment(\.onboardingScenesPaused, ceremonyDay != nil || pickingLibrary)
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
            if v.translation.width < -60, canSwipeForward { next() }
            if v.translation.width > 60 { back() }
        })
        .task { track { await prepare() } }
        .task { await settleArrivalWithoutAsking() }
        .fullScreenCover(item: $ceremonyDay, onDismiss: ceremonyFinished) { day in
            BadgeCeremony(moments: store.pebbleMoments(on: day.id),
                          isPresented: Binding(get: { ceremonyDay != nil },
                                               set: { shown in
                                                   guard !shown else { return }
                                                   PebbleNaming.stamp(day.id, moments: store.pebbleMoments(on: day.id))
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
                lastImport = RecentImport(dayKeys: keys, since: pickerStartedAt)
                pickerOutcome = OnboardingFlow.outcome(existingRecordsWereEmpty: pickerStartedEmpty,
                                                      importedDayKeys: keys, today: Moment.dayKey(for: Date()))
                afterImport()
            }
        }
        .onDisappear { firstPebble.stop() }
    }

    @State private var pickerStartedEmpty = true
    @State private var pickerStartedAt = Date()
    @State private var lastImport: RecentImport?

    private struct RecentImport {
        let dayKeys: Set<String>
        let since: Date
    }

    private var receivedResult: ReceivedResult {
        guard let lastImport else { return ReceivedResult() }
        let photos = store.moments
            .filter { m in m.addedAt.map { $0 >= lastImport.since } ?? false && lastImport.dayKeys.contains(m.dayKey) }
            .sorted { ($0.addedAt ?? .distantPast) < ($1.addedAt ?? .distantPast) }
        guard let day = ReceivedCopy.focusDay(importedDayKeys: lastImport.dayKeys, today: Moment.dayKey(for: Date()))
        else { return ReceivedResult(photos: photos) }
        let gifted = gifts.isGifted(day)
        return ReceivedResult(photos: photos, pebble: gifted ? store.pebbleMoments(on: day) : [], dayGifted: gifted)
    }

    private var startPebble: [Moment] {
        // 방금 받은 하루가 있으면 그 조약돌 — 다시 보기처럼 기록이 이미 있으면 「가장 최근」이 다른 날일 수 있다.
        if let day = receivedDay, gifts.isGifted(day) { return store.pebbleMoments(on: day) }
        return StartScene.latestGiftedDay(dayKeys: store.dayKeys, isGifted: gifts.isGifted)
            .map { store.pebbleMoments(on: $0) } ?? []
    }

    // MARK: 틀

    private var ink: OnboardingInk { light ? .light : .dark }

    private var topBar: some View {
        ZStack {
            HStack(spacing: 7) {
                ForEach(steps.indices, id: \.self) { i in
                    Circle()
                        .fill(i == index ? ink.primary : ink.hairline)
                        .frame(width: 6, height: 6)
                }
            }
            .animation(.easeOut(duration: 0.2), value: index)
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(Face.lineCeremony)
                        .foregroundStyle(ink.secondary)
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
        case .place: placeAnswered
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

    /// 알림 권한이 이미 정해진 기기에선 아침 소식 단계를 빼고 답한 것으로 적는다.
    private func settleArrivalWithoutAsking() async {
        guard !didAskArrivalNotice,
              case .skip(let syncs) = ArrivalAsk.decision(await ArrivalNotice.permission()) else { return }
        // 이미 그 단계까지 왔으면 빼지 않는다 — 보던 화면이 사라지면 번호가 밀린다.
        if steps.firstIndex(of: .arrival).map({ index < $0 }) ?? false { asksArrival = false }
        didAskArrivalNotice = true
        if syncs { await ArrivalNotice.sync(store: store, closures: closures, gifts: gifts) }
    }

    /// iCloud 로 이어 온 사람은 첫 조약돌(사진 권한을 묻는 유일한 곳)을 건너뛴다 — 여기서 안 물으면 기록만 오고
    /// 사진은 로딩만 돈다(2026-10-01 재설치 실기기). 받으면 iCloud 기록을 이 기기 사진과 그 자리에서 잇는다.
    private func continueWithPhotos() {
        Task {
            if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
                _ = await LibraryImporter.requestAccess()
                await CloudIDMapper.refresh(store: store)
            }
            next()
        }
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
            FirstPebbleStep(model: firstPebble, store: store, result: receivedResult,
                            begin: beginFirstPebble,
                            receive: receiveSelected,
                            pickManually: {
                                pickerStartedEmpty = replaying || store.moments.isEmpty
                                pickerStartedAt = Date()
                                pickingLibrary = true
                            },
                            next: next)
        case .continuing:
            CloudStep(remoteDays: remoteDays, dayCount: store.dayKeys.count, actionTitle: "이어서 보기", next: continueWithPhotos)
        case .cloud:
            CloudStep(remoteDays: remoteDays, dayCount: store.dayKeys.count, actionTitle: "다음", next: next)
        case .place:
            PlaceStep(answered: { placeAnswered = true; next() })
        case .arrival:
            ArrivalStep(store: store, closures: closures, gifts: gifts, answered: next)
        case .reminder:
            ReminderStep(store: store, followsArrival: steps.contains(.arrival), next: next)
        case .howTo:
            HowToStep(next: next)
        case .cameraButton:
            CameraButtonStep(next: next)
        case .collection:
            CollectionStep(next: next)
        case .start:
            StartStep(pebble: startPebble, receivedDay: receivedDay.flatMap { gifts.isGifted($0) ? $0 : nil },
                      ready: ready,
                      onCamera: { onFinish(.camera) },
                      onStart: { onFinish(.home) },
                      onOpenDay: { onFinish(.day($0)) })
                .task {
                    // 준비가 오래 걸려도 여기서 붙잡아 두지 않는다 — 남은 일은 홈에서도 뒤에서 이어진다.
                    try? await Task.sleep(for: .seconds(4))
                    waitedLongEnough = true
                }
        }
    }

    /// 디버그 「온보딩 다시 보기」 — 기록이 있어도 새 사용자처럼 증정까지 보여 준다.
    private var replaying: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "debugReplayOnboarding")
        #else
        false
        #endif
    }

    private func beginFirstPebble(_ ask: Bool) async {
        guard await firstPebble.begin(askIfNeeded: ask) else {
            withAnimation(.easeInOut(duration: 0.35)) { skipsFirstPebble = true }
            return
        }
    }

    private func receiveSelected() async {
        let since = Date()
        let (outcome, keys) = await firstPebble.importSelected(store: store, treatsAsNew: replaying)
        importedDayKeys.formUnion(keys)
        if !keys.isEmpty { lastImport = RecentImport(dayKeys: keys, since: since) }
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
        receivedDay = day
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
        // 바로 넘기지 않는다 — 뒤에 「첫 조약돌을 받았어요」 화면이 기다리고 있다(사진이 조약돌로 모이는 장면은
        // 증정이 덮고 있는 동안 멈춰 있다가 이제 돈다). 「다음」을 눌러야 다음 장으로.
    }
}
