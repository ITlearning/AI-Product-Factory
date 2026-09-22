import SwiftUI

/// 자정에 하루가 증정되는 순간.
///
/// 이 앱이 사용자에게 주는 유일한 보상이고, **하루에 한 번뿐이다.**
/// 그래서 짧고 조용해야 한다 — 요란하면 두 번째부터 성가시다.
///
/// 순서: 어둠 → 조약돌이 아래에서 떠올라 **안착** → 그제야 표면이 한 번 훑임 → 날짜가 뒤따라 옴.
///
/// **타임라인은 이 뷰 하나가 쥔다.** 조약돌이 제 `onAppear` 에서 슁을 혼자 돌리던 판은
/// 아직 투명한 돌 위로 빛이 먼저 지나가서, 다 지나간 뒤에 돌이 나타나는 것처럼 보였다.
public struct BadgeCeremony: View {
    private let moments: [Moment]
    @Binding private var isPresented: Bool

    /// 조약돌이 떠오르는 «자리»(크기·높이). 스프링으로 물리감을 준다.
    @State private var risen = false
    /// 조약돌이 «보이는» 정도. 자리와 곡선을 나눠 건다 —
    /// 스프링을 투명도에 같이 걸면 오버슛이 0→1 을 먼저 찍고 감아서
    /// 아직 떠오르는 중인데 이미 다 보이는, 즉 «뚝 떴다가 움직이는» 그림이 된다.
    @State private var lit = false
    /// 표면을 훑는 빛의 진행도. 안착한 뒤 0 → 1 로 지나간다.
    ///
    /// **처음부터 0 으로 존재해야 한다.** `nil` 에서 출발하면 `withAnimation` 이 값 변화가 아니라
    /// 뷰 삽입이 돼 애니메이션이 통째로 날아간다 — 띠가 도착지에 멈춰 선 채 조약돌을
    /// 옅게 덮고 있다가 사라졌다(실측: 「슁이 안 보인다」).
    @State private var sheen: Double = 0
    /// 이름·날짜·닫기.
    @State private var settled = false
    @State private var drift = false

    /// 한 장면의 박자. 숫자를 여기 모아둬야 순서가 어긋나지 않는다.
    private enum Beat {
        static let rise = 0.15          // 떠오르기 시작
        static let riseFade = 0.80      // 다 보이기까지
        static let land = 0.95          // 안착 (촉감이 여기서 온다)
        static let sheenSpan = 0.95     // 표면을 훑는 시간
        static let text = 1.30          // 이름이 뒤따라 오는 시각
    }

    public init(moments: [Moment], isPresented: Binding<Bool>) {
        self.moments = moments
        self._isPresented = isPresented
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 화면 전체에 번지는 그날의 빛. 조약돌 뒤가 아니라 방 전체가 물드는 느낌.
            // 아주 천천히 숨쉰다 — 눈에 띄면 과하고, 멈춰 있으면 죽은 그림이 된다.
            GeometryReader { geo in
                let side = max(geo.size.width, geo.size.height) * 1.15
                DayGradientView(moments: moments, axis: .vertical)
                    .frame(width: side, height: side)
                    .blur(radius: 110)
                    // `drawingGroup()` 은 쓰지 않는다. 블러를 한 번만 굽는 대신 내용을
                    // **뷰 경계에서 잘라** 버려서, 닫을 때 그 사각형 가장자리가 화면 위쪽으로
                    // 삐져나온 그림자처럼 드러났다(실측). 흐린 빛은 경계가 없어야 한다.
                    .scaleEffect(drift ? 1.10 : 0.92)
                    .rotationEffect(.degrees(drift ? 7 : -7))
                    .offset(x: drift ? 22 : -22, y: drift ? -26 : 26)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .ignoresSafeArea()
            .opacity(lit ? 0.42 : 0)
            .allowsHitTesting(false)

            VStack(spacing: 22) {
                Text(Self.openingLine(for: moments, now: Date()))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(lit ? 0.75 : 0))
                    .offset(y: risen ? 0 : 8)

                ZStack {
                    // 처음부터 끝까지 **같은** 조약돌이다. 도중에 다른 뷰로 갈아끼우지 않는다 —
                    // 교체하는 판은 아무리 맞춰도 갈아끼우는 프레임에서 한 번 튄다.
                    DayBadgeView(moments: moments, size: 150, showsCaption: false, sheen: sheen)
                        .scaleEffect(risen ? 1 : 0.5)
                        .offset(y: risen ? 0 : 40)
                        .opacity(lit ? 1 : 0)
                }
                .frame(height: 230)

                VStack(spacing: 8) {
                    if let named = PebbleNaming.name(for: moments) {
                        VStack(spacing: 5) {
                            Text(named.name)
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            // 하루에 한 번 말을 거는 자리. 판단하지 않고 그날을 인정만 한다.
                            Text(named.line)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                    Text(dateText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                    if let span = DayGradient.span(for: moments) {
                        Text("\(DayGradient.timeText(span.from)) – \(DayGradient.timeText(span.to)) · \(moments.count)개")
                            .font(.system(size: 11, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.32))
                    }
                }
                .opacity(settled ? 1 : 0)
                .offset(y: settled ? 0 : 10)
            }

            VStack {
                Spacer()
                Button { isPresented = false } label: {
                    Text("닫기")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 22).padding(.vertical, 10)
                }
                .opacity(settled ? 1 : 0)
                .padding(.bottom, 28)
            }
        }
        .statusBarHidden()
        .onAppear(perform: run)
    }

    private func run() {
        Haptics.prepare()

        // 1) 떠오른다. 자리는 스프링, 투명도는 easeOut — 곡선을 나눠야 «떠오르며 나타난다».
        //    스프링 감쇠를 0.68 → 0.9 로 올렸다. 튕김이 있으면 안착이 두 번처럼 보인다.
        withAnimation(.spring(response: 0.80, dampingFraction: 0.90).delay(Beat.rise)) { risen = true }
        withAnimation(.easeOut(duration: Beat.riseFade).delay(Beat.rise)) { lit = true }

        // 2) 안착. 촉감은 눈이 «닿았다»고 보는 순간과 같이 와야 한다.
        DispatchQueue.main.asyncAfter(deadline: .now() + Beat.land) { Haptics.snapped() }

        // 3) 그제야 표면을 한 번 훑는다. `sheen` 은 이미 0 으로 그려져 있으므로
        //    이건 뷰 삽입이 아니라 값 변화다 — 그래서 실제로 미끄러진다.
        //    끝나고 되돌리지 않는다. 진행도 1 은 스스로 투명해서 0 과 같은 그림이고,
        //    되돌리는 타이머가 없어야 닫았다 다시 열 때 엇박이 안 난다.
        withAnimation(.easeInOut(duration: Beat.sheenSpan).delay(Beat.land)) { sheen = 1 }

        // 4) 이름이 뒤따라 온다.
        withAnimation(.easeOut(duration: 0.55).delay(Beat.text)) { settled = true }

        // 5) 배경이 숨쉬기 시작하는 건 등장이 끝난 뒤다. 등장과 겹치면 GPU 를 나눠 쓰느라
        //    떠오르는 동안 프레임이 떨어진다(반경 110 블러를 계속 변형하는 애니메이션이다).
        DispatchQueue.main.asyncAfter(deadline: .now() + Beat.land + Beat.sheenSpan) {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    /// 첫 줄. **증정은 «끝난 하루»를 건네는 것이라 늘 «오늘»일 수 없다.**
    ///
    /// 자정 트리거가 붙기 전에는 미리 보기(오늘 것)뿐이라 「오늘이 담겼어요」로 고정이었는데,
    /// 실제 증정은 어제나 그 이전이 온다(사흘 만에 열면 사흘 전이 올 수도 있다).
    /// 날짜는 아래에 그대로 새기므로 여기서는 «언제인지»만 틀리지 않으면 된다.
    static func openingLine(for moments: [Moment], now: Date) -> String {
        guard let key = moments.first?.dayKey else { return "하루가 담겼어요" }
        let today = Moment.dayKey(for: now)
        if key == today { return "오늘이 담겼어요" }
        // 새벽 4시 경계를 그대로 써야 «어제»의 뜻이 저장소와 어긋나지 않는다.
        let yesterday = Moment.dayKey(for: now.addingTimeInterval(-86_400))
        if key == yesterday { return "어제가 담겼어요" }
        return "그날이 담겼어요"
    }

    private var dateText: String {
        guard let first = moments.min(by: { $0.capturedAt < $1.capturedAt }) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: first.capturedAt)
    }
}
