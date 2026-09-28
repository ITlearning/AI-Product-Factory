import Photos
import SwiftUI

struct HomeShell: View {
    let store: DayStore
    let inbox: CaptureInbox
    let gifts: GiftLog
    let closures: DayClosures
    // 입양·정리·cloudID·위젯 한 차례 — 온보딩이 넘기는 동안 뒤에서 돌리고 끝나기를 기다린다.
    var prepare: () async -> Void = {}

    @State private var progress: CGFloat = 0
    @State private var dragging = false
    @State private var focusDay: String?
    @State private var scrubbing = false
    @State private var pendingLibraryFocus = false
    // 하루 상세 시트가 닫힐 때마다 올린다 — DayGiftPresenter 가 이 변화만 보고 증정을 시도한다.
    @State private var daySheetDismissedTick = 0
    // 하루 상세 시트가 떠 있는 동안 true — HomeView 가 갱신한다.
    @State private var daySheetPresented = false
    // 카드 시트·한 줌 전체 화면이 떠 있는 동안 true — HomeView 가 onDismiss 에서만 내린다.
    @State private var keepsakePresented = false

    @State private var dragStart: CGFloat = 0

    @State private var axis: Axis?

    private enum Axis { case horizontal, vertical }

    private static let axisDecision: CGFloat = 20

    private static let axisBias: CGFloat = 2.2
    @State private var camera: CaptureEngine?
    @State private var pickingLibrary = false
    // pickingLibrary 는 닫힘 애니메이션 시작에 false 가 된다 — 증정 가드는 커버 onDismiss 에서만 푼다.
    @State private var libraryCoverUp = false
    // 사진첩 시트를 열기 직전 기록이 하나도 없었는지 — 온보딩 증정 하루를 고를지 판단한다.
    @State private var recordsWereEmptyBeforeLibraryImport = false

    @AppStorage("didSwipeToCamera") private var didSwipe = false
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = false
    // 온보딩 또는 기존 사용자 한 장에서 실제로 답을 받았을 때만 true.
    @AppStorage("didAskArrivalNotice") private var didAskArrivalNotice = false
    // 기록 0개에서 사진첩으로 처음 담았을 때 고른 하루 — 증정 뒤 이 값을 지운다.
    @AppStorage("onboardingGiftDay") private var onboardingGiftDay: String?
    // 온보딩 도중 사진을 담으면 기록이 생겨 판정이 바뀐다 — 한 번 띄웠으면 끝낼 때까지 붙잡는다.
    @State private var onboardingLatched = false
    @State private var noticePermission: ArrivalAsk.Permission?
    #if DEBUG
    @State private var showingGate = false
    #if DEBUG
    @AppStorage("debugReplayOnboarding") private var debugReplayOnboarding = false
    #endif
    #endif

    private static let commitDistance: CGFloat = 0.42
    private static let commitVelocity: CGFloat = 420

    var body: some View {
        GeometryReader { geo in
            let _ = Haptics.prepare()
            let w = geo.size.width
            ZStack {
                Tone.pure.ignoresSafeArea()

                HomeView(store: store, gifts: gifts, showsSwipeHint: !didSwipe && !didFinishOnboarding && progress == 0,
                         focusDay: $focusDay, closures: closures, scrubbing: $scrubbing,
                         onDaySheetDismissed: { daySheetDismissedTick += 1 },
                         daySheetPresented: $daySheetPresented,
                         keepsakePresented: $keepsakePresented,
                         onDayClosed: { Task { await HomeWidget.syncWithArrivalNotice(store: store, closures: closures, gifts: gifts) } },
                         onRequestLibraryPicker: openLibraryPicker,
                         holdsArrivals: progress > 0 || libraryCoverUp || daySheetPresented || keepsakePresented)
                    .offset(x: progress * w)
                    .disabled(progress > 0.01)

                cameraSide
                    .offset(x: -w + progress * w)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(swipe(width: w))
            .onChange(of: progress) { _, p in
                if p <= 0.001 { camera?.stop() } else if !dragging { camera?.start() }
            }
            .animation(dragging ? nil : .spring(response: 0.42, dampingFraction: 0.86),
                       value: progress)
        }
        .preferredColorScheme(.dark)
        .onChange(of: store.dayKeys) { _, keys in
            if onboardingGiftDay != nil { onboardingGiftDay = OnboardingGift.retained(onboardingGiftDay, dayKeys: keys) }
        }
        // progress > 0 이면 카메라 쪽이 조금이라도 보인다 — 애니메이션 중에도 값이 바로 바뀌므로
        // 완전히 닫혀 정확히 0 이 될 때만 증정 가드가 풀린다.
        .dayGift(store: store, gifts: gifts, dismissedTick: daySheetDismissedTick,
                 blocksPresentation: daySheetPresented || keepsakePresented || pickingLibrary || libraryCoverUp
                     || progress > 0 || onboarding != .none,
                 onboardingGiftDay: onboardingGiftDay,
                 onCeremonyFinished: handleCeremonyFinished)
        .onChange(of: pickingLibrary) { _, up in if up { libraryCoverUp = true } }
        .fullScreenCover(isPresented: $pickingLibrary, onDismiss: {
            libraryCoverUp = false
            guard pendingLibraryFocus else { return }
            pendingLibraryFocus = false
            focusDay = store.moments
                .filter { $0.addedAt != nil }
                .max { $0.addedAt! < $1.addedAt! }?
                .dayKey
        }) {
            LibraryPickerView(store: store) { importedDayKeys in
                guard !importedDayKeys.isEmpty else { return }
                camera?.confirm("담겼어요")
                progress = 0
                pendingLibraryFocus = true
                if recordsWereEmptyBeforeLibraryImport {
                    onboardingGiftDay = OnboardingGift.firstImportDay(existingRecordsWereEmpty: true,
                                                                      importedDayKeys: Array(importedDayKeys),
                                                                      today: Moment.dayKey(for: Date()))
                }
                Task { await HomeWidget.syncWithArrivalNotice(store: store, closures: closures, gifts: gifts) }
            }
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {

            if progress == 0 && onboarding == .none {
                Button { showingGate = true } label: {
                    Image(systemName: "wrench.adjustable").foregroundStyle(Tone.hairline)
                }
                .padding(.trailing, 20).padding(.top, 14)
            }
        }
        .sheet(isPresented: $showingGate) { SpikeView(inbox: inbox, store: store, gifts: gifts, closures: closures) }
        #endif
        .overlay { onboardingLayer.animation(.easeInOut(duration: 0.45), value: onboarding) }
        .onChange(of: store.isLoaded, initial: true) { _, _ in
            if liveOnboarding == .full { onboardingLatched = true }
        }
        .task { noticePermission = await ArrivalNotice.permission() }
        .onChange(of: settlesArrivalAsk, initial: true) { _, _ in settleArrivalAsk() }
        #if DEBUG
        .onChange(of: showingGate) { _, up in
            if !up && debugReplayOnboarding && store.isLoaded { onboardingLatched = true }
        }
        #endif
    }

    private var rawOnboarding: OnboardingGate.Presentation {
        OnboardingGate.presentation(isLoaded: store.isLoaded, didFinishOnboarding: didFinishOnboarding,
                                    hasRecords: !store.dayKeys.isEmpty, didAskArrivalNotice: didAskArrivalNotice)
    }

    private var liveOnboarding: OnboardingGate.Presentation {
        OnboardingGate.resolve(rawOnboarding, noticePermission: noticePermission)
    }

    private var settlesArrivalAsk: Bool {
        guard !onboardingLatched, rawOnboarding == .arrivalAskOnly, let noticePermission else { return false }
        return ArrivalAsk.decision(noticePermission) != .ask
    }

    private func settleArrivalAsk() {
        guard settlesArrivalAsk, let noticePermission,
              case .skip(let syncs) = ArrivalAsk.decision(noticePermission) else { return }
        didAskArrivalNotice = true
        if syncs { Task { await ArrivalNotice.sync(store: store, closures: closures, gifts: gifts) } }
    }

    // 로드 전(undecided)에도 증정은 막힌다 — 판정이 서기 전 커버가 먼저 뜨지 않게.
    private var onboarding: OnboardingGate.Presentation {
        onboardingLatched ? .full : liveOnboarding
    }

    @ViewBuilder
    private var onboardingLayer: some View {
        switch onboarding {
        case .full:
            OnboardingView(store: store, gifts: gifts, closures: closures, prepare: prepare,
                           onFinish: finishOnboarding)
                .transition(.opacity)
        case .arrivalAskOnly:
            ArrivalAskOverlay(store: store, closures: closures, gifts: gifts)
                .transition(.opacity)
        case .undecided, .none:
            EmptyView()
        }
    }

    private func finishOnboarding(openCamera: Bool) {
        didFinishOnboarding = true
        #if DEBUG
        debugReplayOnboarding = false
        #endif
        if openCamera {
            makeCamera()
            progress = 1
        }
        withAnimation(.easeInOut(duration: 0.45)) { onboardingLatched = false }
    }

    @ViewBuilder
    private var cameraSide: some View {
        if let camera {

            CaptureScreen(engine: camera, onClose: { progress = 0 }, onLibrary: openLibraryPicker)
        }
    }

    private func openLibraryPicker() {
        recordsWereEmptyBeforeLibraryImport = store.moments.isEmpty
        libraryCoverUp = true
        pickingLibrary = true
    }

    private func swipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { v in
                guard !scrubbing else { return }
                let dx = v.translation.width, dy = v.translation.height
                if axis == nil {

                    guard max(abs(dx), abs(dy)) >= Self.axisDecision else { return }
                    axis = abs(dx) > abs(dy) * Self.axisBias ? .horizontal : .vertical
                }
                guard axis == .horizontal else { return }
                if !dragging {

                    guard !(progress == 0 && dx < 0) else { axis = .vertical; return }
                    dragStart = progress
                    dragging = true
                    if camera == nil { makeCamera() }
                }
                progress = rubberBanded(dragStart + dx / width)
            }
            .onEnded { v in
                defer { axis = nil }
                guard dragging else { return }
                dragging = false

                let vx = v.predictedEndTranslation.width - v.translation.width
                let wasHome = dragStart < 0.5
                let far = wasHome ? progress > Self.commitDistance
                                  : progress < 1 - Self.commitDistance
                let fast = abs(vx) > Self.commitVelocity && ((vx > 0) == wasHome)
                let flipped = far || fast
                let open = wasHome ? flipped : !flipped
                progress = open ? 1 : 0

                if open != (dragStart > 0.5) { Haptics.snapped() }
                if open { didSwipe = true }
            }
    }

    private func rubberBanded(_ x: CGFloat) -> CGFloat {
        if x < 0 { return x * 0.28 }
        if x > 1 { return 1 + (x - 1) * 0.28 }
        return x
    }

    private func makeCamera() {
        guard camera == nil else { return }
        camera = CaptureEngine(destination: { ShotStore.directory },
                               onRecorded: { m in
            store.add(m)
            Task {
                // 처음 찍을 때만 묻는다 — 이미 물어봤으면 상태가 notDetermined 가 아니다.
                if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
                    _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                }
                await store.waitUntilLoaded()
                await AssetAdopter.adopt(m, store: store)
                await HomeWidget.syncWithArrivalNotice(store: store, closures: closures, gifts: gifts)
            }
        })
    }

    // 4~8시 사이에 앱을 열어 그 자리에서 받았으면 아침 알림이 뒤늦게 오지 않게 그 날짜만 지운다.
    // 아침 소식은 온보딩(기존 사용자는 한 장)에서 이미 묻는다 — 증정 뒤엔 묻지 않는다.
    private func handleCeremonyFinished(_ dayKey: String) {
        if dayKey == onboardingGiftDay { onboardingGiftDay = nil }
        Task { await ArrivalNotice.clear(dayKey: dayKey) }
        HomeWidget.refresh(store: store, gifts: gifts)
    }
}
