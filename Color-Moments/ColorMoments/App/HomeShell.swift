import Photos
import SwiftUI
import UserNotifications

struct HomeShell: View {
    let store: DayStore
    let inbox: CaptureInbox
    let gifts: GiftLog
    let closures: DayClosures

    @State private var progress: CGFloat = 0
    @State private var dragging = false
    @State private var focusDay: String?
    @State private var scrubbing = false
    @State private var pendingLibraryFocus = false
    // 하루 상세 시트가 닫힐 때마다 올린다 — DayGiftPresenter 가 이 변화만 보고 증정을 시도한다.
    @State private var daySheetDismissedTick = 0
    // 하루 상세 시트가 떠 있는 동안 true — HomeView 가 갱신한다.
    @State private var daySheetPresented = false

    @State private var dragStart: CGFloat = 0

    @State private var axis: Axis?

    private enum Axis { case horizontal, vertical }

    private static let axisDecision: CGFloat = 20

    private static let axisBias: CGFloat = 2.2
    @State private var camera: CaptureEngine?
    @State private var pickingLibrary = false
    // pickingLibrary 는 닫힘 애니메이션 시작에 false 가 된다 — 증정 가드는 커버 onDismiss 에서만 푼다.
    @State private var libraryCoverUp = false

    @AppStorage("didSwipeToCamera") private var didSwipe = false
    @AppStorage("didSeeFirstRun") private var didSeeFirstRun = false
    // 첫 증정이 끝난 뒤 딱 한 번만 아침 도착 소식을 물어본다.
    @AppStorage("didAskArrivalNotice") private var didAskArrivalNotice = false
    @State private var showingArrivalNoticeAsk = false
    #if DEBUG
    @State private var showingGate = false
    #endif

    private static let commitDistance: CGFloat = 0.42
    private static let commitVelocity: CGFloat = 420

    var body: some View {
        GeometryReader { geo in
            let _ = Haptics.prepare()
            let w = geo.size.width
            ZStack {
                Tone.pure.ignoresSafeArea()

                HomeView(store: store, showsSwipeHint: !didSwipe && didSeeFirstRun && progress == 0,
                         focusDay: $focusDay, closures: closures, scrubbing: $scrubbing,
                         onDaySheetDismissed: { daySheetDismissedTick += 1 },
                         daySheetPresented: $daySheetPresented,
                         onDayClosed: { Task { await HomeWidget.syncWithArrivalNotice(store: store, closures: closures, gifts: gifts) } })
                    .offset(x: progress * w)
                    .disabled(progress > 0.01)

                cameraSide
                    .offset(x: -w + progress * w)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(swipe(width: w))
            .overlay {
                // 이미 쓸어 본 사람에게는 띄우지 않는다 — 기존 설치본도 여기로 들어온다.
                if !didSeeFirstRun && !didSwipe {
                    FirstRunOverlay {
                        withAnimation(.easeOut(duration: 0.25)) { didSeeFirstRun = true }
                    }
                }
            }

            .onChange(of: progress) { _, p in
                if p <= 0.001 { camera?.stop() } else if !dragging { camera?.start() }
            }
            .animation(dragging ? nil : .spring(response: 0.42, dampingFraction: 0.86),
                       value: progress)
        }
        .preferredColorScheme(.dark)
        // progress > 0 이면 카메라 쪽이 조금이라도 보인다 — 애니메이션 중에도 값이 바로 바뀌므로
        // 완전히 닫혀 정확히 0 이 될 때만 증정 가드가 풀린다.
        .dayGift(store: store, gifts: gifts, dismissedTick: daySheetDismissedTick,
                 blocksPresentation: daySheetPresented || pickingLibrary || libraryCoverUp || progress > 0,
                 onCeremonyFinished: handleCeremonyFinished)
        .alert("조약돌이 도착하면 아침에 알려 드릴까요?", isPresented: $showingArrivalNoticeAsk) {
            Button("알려 주세요") {
                Task {
                    let granted = (try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound])) ?? false
                    if granted { await ArrivalNotice.sync(store: store, closures: closures, gifts: gifts) }
                }
            }
            Button("괜찮아요", role: .cancel) {}
        }
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
            LibraryPickerView(store: store) { n in
                guard n > 0 else { return }
                camera?.confirm("담겼어요")
                progress = 0
                pendingLibraryFocus = true
                Task { await HomeWidget.syncWithArrivalNotice(store: store, closures: closures, gifts: gifts) }
            }
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {

            if progress == 0 {
                Button { showingGate = true } label: {
                    Image(systemName: "wrench.adjustable").foregroundStyle(Tone.hairline)
                }
                .padding(.trailing, 20).padding(.top, 14)
            }
        }
        .sheet(isPresented: $showingGate) { SpikeView(inbox: inbox, store: store, gifts: gifts, closures: closures) }
        #endif
    }

    @ViewBuilder
    private var cameraSide: some View {
        if let camera {

            CaptureScreen(engine: camera, onClose: { progress = 0 }, onLibrary: {
                libraryCoverUp = true
                pickingLibrary = true
            })
        }
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
                await AssetAdopter.adopt(m, store: store)
                await HomeWidget.syncWithArrivalNotice(store: store, closures: closures, gifts: gifts)
            }
        })
    }

    // 4~8시 사이에 앱을 열어 그 자리에서 받았으면 아침 알림이 뒤늦게 오지 않게 그 날짜만 지운다.
    // 물어보는 건 마무리 여부와 무관하게 "첫 증정" 한 번뿐.
    private func handleCeremonyFinished(_ dayKey: String) {
        Task { await ArrivalNotice.clear(dayKey: dayKey) }
        HomeWidget.refresh(store: store, gifts: gifts)
        guard !didAskArrivalNotice else { return }
        didAskArrivalNotice = true
        showingArrivalNoticeAsk = true
    }
}
