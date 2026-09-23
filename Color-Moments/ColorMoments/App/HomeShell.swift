import Photos
import SwiftUI

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

    @State private var dragStart: CGFloat = 0

    @State private var axis: Axis?

    private enum Axis { case horizontal, vertical }

    private static let axisDecision: CGFloat = 20

    private static let axisBias: CGFloat = 2.2
    @State private var camera: CaptureEngine?
    @State private var pickingLibrary = false

    @AppStorage("didSwipeToCamera") private var didSwipe = false
    @AppStorage("didSeeFirstRun") private var didSeeFirstRun = false
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
                         onDaySheetDismissed: { daySheetDismissedTick += 1 })
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
        .dayGift(store: store, gifts: gifts, closures: closures, dismissedTick: daySheetDismissedTick)
        .fullScreenCover(isPresented: $pickingLibrary, onDismiss: {
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

            CaptureScreen(engine: camera, onClose: { progress = 0 }, onLibrary: { pickingLibrary = true })
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
            }
        })
    }
}
