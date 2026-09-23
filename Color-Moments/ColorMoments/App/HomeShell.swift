import SwiftUI

/// 홈과 카메라를 나란히 들고 **좌→우 스와이프로 넘기는** 껍데기. `DESIGN.md` §1.2.
///
/// **홈에 셔터 버튼이 없다.** 촬영 경로는 둘뿐이다 —
/// 잠금화면 카메라 컨트롤 1초(주 진입)와 여기서의 스와이프.
/// 근거는 SPEC §1 의 「앱을 여는 건 찍으러가 아니라 보러 오는 것」이고,
/// 셔터를 화면에 두면 그 말과 화면이 어긋난다.
///
/// 홈이 오른쪽으로 밀리고 카메라가 왼쪽에서 따라 들어온다. 손을 떼면 되돌아간다.
struct HomeShell: View {
    let store: DayStore
    let inbox: CaptureInbox
    let gifts: GiftLog

    /// 0 = 홈, 1 = 카메라. 드래그 중에는 그 사이를 연속으로 오간다.
    @State private var progress: CGFloat = 0
    @State private var dragging = false
    @State private var camera: CaptureEngine?
    /// 스와이프를 한 번이라도 성공했는가. 성공 전까지 힌트를 계속 보여준다.
    @AppStorage("didSwipeToCamera") private var didSwipe = false
    #if DEBUG
    @State private var showingGate = false
    #endif

    /// 손을 뗐을 때 넘어갈지 되돌아갈지. 거리 반, 속도 반으로 본다 —
    /// 거리만 보면 빠르게 튕긴 제스처가 무시되고, 속도만 보면 천천히 끝까지 끈 제스처가 무시된다.
    private static let commitDistance: CGFloat = 0.42
    private static let commitVelocity: CGFloat = 420

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                Tone.pure.ignoresSafeArea()

                HomeView(store: store, showsSwipeHint: !didSwipe && progress == 0)
                    .offset(x: progress * w)
                    .disabled(progress > 0.01)

                cameraSide
                    .offset(x: -w + progress * w)
                    .opacity(progress < 0.01 ? 0 : 1)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(swipe(width: w))
            .animation(dragging ? nil : .spring(response: 0.42, dampingFraction: 0.86),
                       value: progress)
        }
        .preferredColorScheme(.dark)
        .dayGift(store: store, gifts: gifts)
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            // 계측기. 릴리즈엔 안 들어간다. 잠금화면 수신 로그가 사진첩 B 경로 작업에 아직 필요하다.
            if progress == 0 {
                Button { showingGate = true } label: {
                    Image(systemName: "wrench.adjustable").foregroundStyle(Tone.hairline)
                }
                .padding(.trailing, 20).padding(.top, 14)
            }
        }
        .sheet(isPresented: $showingGate) { SpikeView(inbox: inbox, store: store, gifts: gifts) }
        #endif
    }

    @ViewBuilder
    private var cameraSide: some View {
        if let camera {
            // 되돌아가는 길도 스와이프다. 닫기 버튼은 두지 않는다(§3.5 «쓸면 돌아가기»).
            CaptureScreen(engine: camera)
        }
    }

    // MARK: 제스처

    private func swipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                // 세로 스크롤을 빼앗지 않는다 — 가로가 확실히 우세할 때만 잡는다.
                guard abs(v.translation.width) > abs(v.translation.height) * 1.4 else { return }
                if camera == nil { makeCamera() }
                dragging = true
                let raw = (progress == 0 ? v.translation.width : width + v.translation.width) / width
                progress = rubberBanded(raw)
            }
            .onEnded { v in
                guard dragging else { return }
                dragging = false
                let vx = v.predictedEndTranslation.width - v.translation.width
                let goingRight = v.translation.width > 0
                let far = goingRight ? progress > Self.commitDistance
                                     : progress < 1 - Self.commitDistance
                let fast = abs(vx) > Self.commitVelocity && (goingRight == (vx > 0))
                let open = goingRight ? (far || fast) : !(far || fast)
                progress = open ? 1 : 0
                if open { didSwipe = true }
            }
    }

    /// 끝을 넘어가면 저항이 붙는다. 선형으로 따라가면 화면이 캔버스처럼 끌려 나온다.
    private func rubberBanded(_ x: CGFloat) -> CGFloat {
        if x < 0 { return x * 0.28 }
        if x > 1 { return 1 + (x - 1) * 0.28 }
        return x
    }

    private func makeCamera() {
        guard camera == nil else { return }
        camera = CaptureEngine(destination: { ShotStore.directory },
                               onRecorded: { store.add($0) })
    }
}
