import Photos
import SwiftUI

struct HomeShell: View {
    let store: DayStore
    let inbox: CaptureInbox
    let gifts: GiftLog
    let closures: DayClosures
    // 입양·정리·cloudID·위젯 한 차례 — 온보딩이 넘기는 동안 뒤에서 돌리고 끝나기를 기다린다.
    var prepare: () async -> Void = {}

    /// 0 홈, 1 카메라(왼쪽에서 들어옴), -1 모은 조약돌(오른쪽에서 들어옴).
    @State private var progress: CGFloat = 0
    @State private var dragSide: SwipeSide?
    /// 모은 조약돌은 처음 열 때 만든다 — 한 번도 안 연 사람에게 비용을 쓰지 않는다.
    @State private var collectionLoaded = false
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
    // iOS 18 은 스크롤이 가로챈 드래그를 onEnded 없이 취소한다 — 끝나든 취소되든 false 로 돌아오는 이 값으로 판정을 푼다.
    @GestureState private var swipeHeld = false

    private enum Axis { case horizontal, vertical }

    private static let axisDecision: CGFloat = 20

    private static let axisBias: CGFloat = 2.2
    /// 왼쪽으로 끌어 모은 조약돌을 여는 건 오른쪽 가장자리 이 폭 안에서 시작할 때만 — 안쪽은 사진 더미 넘기기(왼쪽 튕기기)가 쓴다.
    private static let edgeZone: CGFloat = 40

    private enum SwipeSide { case camera, collection }
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
    @State private var showingSettings = false
    @State private var openDayRequest: String?
    #if DEBUG
    @State private var showingGate = false
    #if DEBUG
    @AppStorage("debugReplayOnboarding") private var debugReplayOnboarding = false
    @AppStorage(FrameMeterBadge.homeKey) private var showsFrameMeter = false
    #endif
    #endif

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let onboardingFade = Animation.easeInOut(duration: 0.8)

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
                         holdsArrivals: progress != 0 || libraryCoverUp || daySheetPresented || keepsakePresented
                             || showingSettings,
                         openDay: $openDayRequest)
                    .offset(x: progress * w)
                    .disabled(abs(progress) > 0.01)

                cameraSide
                    .offset(x: -w + progress * w)

                if collectionLoaded {
                    PebbleCollectionView(store: store, gifts: gifts, closures: closures, onClose: { progress = 0 })
                        .offset(x: w + progress * w)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(swipe(width: w))
            .onChange(of: progress) { _, p in
                if p <= 0.001 { camera?.stop() } else if !dragging { camera?.start() }
            }
            .onChange(of: swipeHeld) { _, held in
                // onEnded 가 먼저 돌게 한 박자 미룬다.
                if !held { Task { @MainActor in settleCancelledSwipe() } }
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
                     || showingSettings || progress != 0 || onboarding != .none,
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
        .overlay(alignment: .topTrailing) {
            if progress == 0 && onboarding == .none {
                HStack(spacing: 4) {
                    #if DEBUG
                    Button { showingGate = true } label: {
                        Image(systemName: "wrench.adjustable").foregroundStyle(Tone.hairline)
                            .frame(width: Shape2.minTouch, height: Shape2.minTouch)
                    }
                    #endif
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape").foregroundStyle(Tone.tertiary)
                            .frame(width: Shape2.minTouch, height: Shape2.minTouch)
                    }
                    .accessibilityLabel("설정")
                }
                .padding(.trailing, 8).padding(.top, 2)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(preview: store.finishedDayKeys.max().map { store.pebbleMoments(on: $0) }
                .flatMap { $0.isEmpty ? nil : $0 } ?? SettingsSheet.sample)
        }
        #if DEBUG
        .sheet(isPresented: $showingGate) { SpikeView(inbox: inbox, store: store, gifts: gifts, closures: closures) }
        .overlay(alignment: .bottom) {
            if showsFrameMeter { FrameMeterBadge().allowsHitTesting(true).padding(.bottom, 4) }
        }
        #endif
        .overlay { onboardingLayer.animation(reduceMotion ? nil : Self.onboardingFade, value: onboarding) }
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

    private func finishOnboarding(_ exit: OnboardingExit) {
        didFinishOnboarding = true
        #if DEBUG
        debugReplayOnboarding = false
        #endif
        if exit == .camera {
            makeCamera()
            progress = 1
        }
        // 밝은 마지막 화면에서 어두운 홈으로 — 길게 겹쳐 튀지 않게 한다.
        withAnimation(reduceMotion ? nil : Self.onboardingFade) { onboardingLatched = false }
        if case .day(let key) = exit {
            // 온보딩이 다 걷힌 뒤에 연다 — 걷히는 중에 시트가 올라오면 두 화면이 겹쳐 보인다.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.1 : 0.8))
                openDayRequest = key
            }
        }
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

    /// 취소된 드래그가 남긴 판정을 푼다 — 가로로 끌던 중이면 가까운 쪽으로 붙인다.
    private func settleCancelledSwipe() {
        guard !swipeHeld else { return }
        axis = nil
        dragSide = nil
        guard dragging else { return }
        dragging = false
        progress = progress > 0.5 ? 1 : (progress < -0.5 ? -1 : 0)
    }

    private func swipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .updating($swipeHeld) { _, held, _ in held = true }
            .onChanged { v in
                guard !scrubbing else { return }
                let dx = v.translation.width, dy = v.translation.height
                if axis == nil {

                    guard max(abs(dx), abs(dy)) >= Self.axisDecision else { return }
                    axis = abs(dx) > abs(dy) * Self.axisBias ? .horizontal : .vertical
                }
                guard axis == .horizontal else { return }
                if !dragging {
                    let side: SwipeSide
                    if progress > 0.5 {
                        side = .camera
                    } else if progress < -0.5 {
                        side = .collection
                    } else if dx > 0 {
                        side = .camera
                    } else {
                        guard v.startLocation.x >= width - Self.edgeZone else { axis = .vertical; return }
                        side = .collection
                    }
                    dragSide = side
                    dragStart = progress
                    dragging = true
                    if side == .camera, camera == nil { makeCamera() }
                    if side == .collection { collectionLoaded = true }
                }
                let raw = dragStart + dx / width
                progress = dragSide == .collection ? rubberBandedCollection(raw) : rubberBanded(raw)
            }
            .onEnded { v in
                defer { axis = nil; dragSide = nil }
                guard dragging else { return }
                dragging = false

                let vx = v.predictedEndTranslation.width - v.translation.width
                if dragSide == .collection {
                    let wasHome = dragStart > -0.5
                    let far = wasHome ? progress < -Self.commitDistance : progress > -1 + Self.commitDistance
                    let fast = abs(vx) > Self.commitVelocity && ((vx < 0) == wasHome)
                    let open = wasHome ? (far || fast) : !(far || fast)
                    progress = open ? -1 : 0
                    if open != (dragStart < -0.5) { Haptics.snapped() }
                    return
                }
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

    private func rubberBandedCollection(_ x: CGFloat) -> CGFloat {
        if x > 0 { return x * 0.28 }
        if x < -1 { return -1 + (x + 1) * 0.28 }
        return x
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
                    _ = await LibraryImporter.requestAccess()
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
