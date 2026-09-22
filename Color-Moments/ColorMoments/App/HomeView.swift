import SwiftUI

/// 몽돌의 홈. **수집물이 본체다.**
///
/// 앱을 여는 행위는 «찍으러»가 아니라 «보러» 오는 것이다 — 주 진입은 잠금화면 카메라 컨트롤
/// 1초이고, 그게 「앱을 열어 회고하는」 경쟁 앱들과 이 제품이 갈리는 지점이다(설계 문서 비교표).
/// 그래서 앱을 열면 카메라가 아니라 모은 조약돌이 보인다.
///
/// 지키는 제약 넷 (설계 문서):
/// - **오늘 색은 안 보여준다.** 담겼다는 것만 한 줄로 알린다 — 찍혔는지조차 모르면 불안하지만,
///   색을 보여주면 「자정에 열린다」가 그 자리에서 깨진다.
/// - **격자로 깔지 않는다.** 빈 날이 구멍으로 보이면 그 순간 스트릭이 된다.
/// - **스트릭·성취는 영구 비목표.** 연속 일수도, 「며칠째」도 없다.
/// - **재촉하지 않는다.** 미보정 표시·확인 요청을 넣지 않는다.
struct HomeView: View {
    private let store: DayStore
    private let inbox: CaptureInbox
    private let gifts: GiftLog

    /// **셔터를 누르기 전에는 만들지 않는다.** 홈이 `AVCaptureSession` 을 계속 붙들고 있을
    /// 이유가 없다 — 앱을 여는 행위는 보러 오는 것이지 찍으러 오는 것이 아니다.
    /// 카메라 권한도 실제로 찍으러 갈 때 물어야 첫 화면이 권한 팝업이 되지 않는다.
    @State private var camera: CaptureEngine?
    @State private var shooting = false
    #if DEBUG
    @State private var showingGate = false
    #endif

    init(store: DayStore, inbox: CaptureInbox, gifts: GiftLog) {
        self.store = store
        self.inbox = inbox
        self.gifts = gifts
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                today
                collection
                Spacer(minLength: 0)
                shutter
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.04).ignoresSafeArea())
            .navigationTitle("몽돌")
            .toolbarBackground(Color(white: 0.04), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #if DEBUG
            .toolbar {
                // 계측기는 릴리즈에 안 들어간다. 잠금화면 수신 로그가 사진첩 B 경로 작업에 필요해
                // 「게이트 통과 후 버린다」 대신 DEBUG 뒤로 물렸다.
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingGate = true } label: { Image(systemName: "wrench.adjustable") }
                        .tint(.gray)
                }
            }
            .sheet(isPresented: $showingGate) { SpikeView(inbox: inbox, store: store, gifts: gifts) }
            #endif
            .fullScreenCover(isPresented: $shooting) {
                if let camera {
                    CaptureScreen(engine: camera, onClose: { shooting = false })
                }
            }
        }
        .preferredColorScheme(.dark)
        .dayGift(store: store, gifts: gifts)
    }

    // MARK: 오늘 — 담겼다는 것만. 색은 자정에.

    private var today: some View {
        let count = store.today.count
        return VStack(alignment: .leading, spacing: 3) {
            Text(count == 0 ? "오늘은 아직 비어 있어요" : "오늘 \(count)개 담겼어요")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Text(count == 0 ? "지나다 눈에 걸리는 게 있으면 눌러요" : "색은 자정에 열려요")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.09), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20).padding(.top, 4)
    }

    // MARK: 모은 하루 — 줄이지 격자가 아니다

    @ViewBuilder
    private var collection: some View {
        if store.finishedDayKeys.isEmpty {
            empty
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("모은 하루")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 20)
                BadgeRowView(store: store)
                    .padding(.leading, 16)
            }
            .padding(.top, 28)
        }
    }

    /// 첫날. **아직 온보딩이 아니다** — Q4 는 사진첩 B 경로를 붙인 뒤에 짠다
    /// (설치 즉시 과거 사진으로 조약돌이 생기면 이 빈 화면 자체가 거의 사라진다).
    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 30, weight: .thin))
                .foregroundStyle(.white.opacity(0.22))
            Text("아직 모은 하루가 없어요")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
            Text("오늘 담은 것은 자정에 조약돌이 돼요")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.32))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    // MARK: 촬영

    private var shutter: some View {
        VStack(spacing: 11) {
            Button {
                if camera == nil {
                    camera = CaptureEngine(destination: { ShotStore.directory },
                                           onRecorded: { store.add($0) })
                }
                shooting = true
            } label: {
                Circle()
                    .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 70, height: 70)
                    .overlay(Circle().fill(.white).frame(width: 57, height: 57))
            }
            .buttonStyle(.plain)
            Text("잠금화면 카메라 컨트롤로도 담을 수 있어요")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.32))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 26)
    }
}
