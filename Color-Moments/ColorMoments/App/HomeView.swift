import SwiftUI

/// 몽돌의 홈. **열린 하루들이 세로로 이어지는 곳이다** (`DESIGN.md` §1.1).
///
/// 별도의 「모은 하루」 화면은 없다. 한 하루 = 겹친 사진 더미 + 우측 하단 조약돌 + 이름·날짜,
/// 이 덩어리가 세로로 반복된다. **1일차에도 7일차에도 1년차에도 화면 구성이 같다.**
///
/// 지키는 제약 (SPEC §2 · DESIGN §4 «손대면 안 되는 것»):
/// - **오늘 색은 안 보여준다.** 담겼다는 것만 상단 한 줄로. 조약돌 줄에도 오늘은 없다.
/// - **격자가 아니다.** 빈 날이 구멍으로 보이면 그 순간 스트릭이 된다.
/// - **가로 스크롤 없음.** 좌우 스와이프는 카메라가 가져간다(§1.3).
/// - **재촉하지 않는다.**
struct HomeView: View {
    let store: DayStore
    /// 아직 스와이프를 성공한 적이 없는가. 있으면 「쓸면 담기」 힌트를 계속 보여준다.
    let showsSwipeHint: Bool

    @State private var opened: OpenedDay?
    @State private var topDayKey: String?
    @State private var scrolling = false

    private struct OpenedDay: Identifiable { let id: String }

    private var days: [String] { store.finishedDayKeys }

    var body: some View {
        ZStack {
            Tone.base.ignoresSafeArea()
            backdrop
            content
            bottomFade
            if scrolling, let label = monthLabel { monthPill(label) }
            if showsSwipeHint { swipeHint }
        }
        .sheet(item: $opened) { day in
            DayMomentsView(dayKey: day.id, store: store)
        }
    }

    // MARK: 그날 색이 공간을 물들인다 — §1.7
    //
    // **blur 130 을 그대로 쓰지 않는다.** 이미 매끈한 그라데이션을 130 으로 흐려봐야
    // 60 과 눈으로 구분되지 않는데 비용만 몇 배다. 스크롤되는 화면이라 그 차이가 프레임에 그대로 온다.
    // (§4 — 번짐 opacity 의 «정확한 값»은 손대도 되는 것, 층위 순서 증정 > 하루 상세 > 홈만 지킨다.)

    @ViewBuilder
    private var backdrop: some View {
        if let key = topDayKey ?? days.first {
            DayGradientView(moments: store.moments(on: key), axis: .vertical)
                .blur(radius: 60)
                .opacity(0.16)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.45), value: key)
                .allowsHitTesting(false)
        }
    }

    // MARK: 본문

    private var content: some View {
        GeometryReader { geo in
            let blockWidth = geo.size.width - 56      // 좌우 여백 28
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("몽돌").font(Face.wordmark).foregroundStyle(Tone.primary)
                    Spacer().frame(height: 22)
                    todayLine
                    Spacer().frame(height: 38)

                    if days.isEmpty {
                        EmptyDayBlock(width: blockWidth)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 64) {
                            ForEach(days, id: \.self) { key in
                                Button { opened = OpenedDay(id: key) } label: {
                                    DayBlock(moments: store.moments(on: key), width: blockWidth)
                                }
                                .buttonStyle(.plain)
                                // 다음 하루는 화면 아래에 «희미하게» 걸친다.
                                // **blur 로 하지 말 것**(§3.1) — 스크롤되는 뷰에 실시간 blur 를 걸면
                                // 프레임이 떨어진다. 원본이 4032×3024 라 더 그렇다.
                                .scrollTransition { c, phase in
                                    c.opacity(phase.isIdentity ? 1 : 0.5)
                                     .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                }
                                .onScrollVisibilityChange(threshold: 0.6) { visible in
                                    if visible { topDayKey = key }
                                }
                            }
                        }
                    }
                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 28)
                .padding(.top, 72 - geo.safeAreaInsets.top)
            }
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                withAnimation(.easeOut(duration: 0.2)) { scrolling = phase.isScrolling }
            }
        }
    }

    /// 한 줄 두 톤. 앞은 primary, 「· 색은…」은 tertiary (§3.1).
    private var todayLine: some View {
        let n = store.today.count
        return Group {
            if n == 0 {
                Text("오늘은 아직 비어 있어요").foregroundStyle(Tone.primary)
                    + Text("  ·  왼쪽에서 쓸어 담아요").foregroundStyle(Tone.tertiary)
            } else {
                Text("오늘 \(n)개 담겼어요").foregroundStyle(Tone.primary)
                    + Text("  ·  색은 자정에 열려요").foregroundStyle(Tone.tertiary)
            }
        }
        .font(Face.today)
    }

    // MARK: 먼 과거로 가는 법 — §1.4
    //
    // **연·월까지만.** 일 단위를 보여주면 달력이 되고 빈 날이 드러나 「격자 금지」가 깨진다.

    private var monthLabel: String? {
        guard let key = topDayKey, key.count >= 7 else { return nil }
        let parts = key.split(separator: "-")
        guard parts.count >= 2 else { return nil }
        return "\(parts[0])년 \(Int(parts[1]) ?? 0)월"
    }

    private func monthPill(_ label: String) -> some View {
        VStack {
            HStack {
                Spacer()
                Text(label)
                    .font(Face.caption).monospacedDigit()
                    .foregroundStyle(Tone.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.white.opacity(0.10), in: Capsule())
                    .padding(.trailing, 14)
            }
            Spacer()
        }
        .padding(.top, 120)
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    // MARK: 쓸면 담기 — §3.1
    //
    // 노출 조건은 **「한 번도 성공 못 했으면 계속」**이다(Tabber 결정 2026-09-23).
    // 날짜·횟수 기반이면 못 보고 놓친 사람은 앱 안에서 찍는 법을 영영 못 찾는다 —
    // 셔터가 없으므로(§1.2) 이건 재촉이 아니라 유일한 경로 표시다.

    private var swipeHint: some View {
        // **글자를 세로로 세운다.** 가로로 두면 28pt 여백을 넘어 사진 위에 겹쳐 읽히지 않는다(실측).
        // 왼쪽 가장자리 여백 안에서만 살아야 본문을 건드리지 않는다.
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Tone.tertiary)
                .frame(width: 3, height: 34)
            Text("쓸면 담기")
                .font(.system(size: 11))
                .foregroundStyle(Tone.tertiary)
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(width: 12, height: 62)
            Spacer()
        }
        .padding(.leading, 5)
        .allowsHitTesting(false)
    }

    private var bottomFade: some View {
        VStack {
            Spacer()
            LinearGradient(colors: [.clear, Tone.base], startPoint: .top, endPoint: .bottom)
                .frame(height: 110)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// 첫날. 빈 자리를 그려 **다음에 여기에 무엇이 놓이는지 형태로 알려준다** (§3.7).
struct EmptyDayBlock: View {
    let width: CGFloat
    private var k: CGFloat { width / 334 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Shape2.cardFront * k, style: .continuous)
                    .strokeBorder(Tone.hairline, style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                    .frame(width: 314 * k, height: 320 * k)
                    .offset(x: 10 * k)
                PebbleShape(top: 0.44, bottom: 0.40)
                    .strokeBorder(Tone.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .frame(width: 84 * k * Shape2.pebbleRatio, height: 84 * k)
                    .offset(x: 272 * k, y: 300 * k)
            }
            .frame(width: width, height: 388 * k, alignment: .topLeading)
            Spacer().frame(height: 26 * k)
            Text("오늘 담은 것은 자정에 조약돌이 돼요")
                .font(Face.guide).foregroundStyle(Tone.tertiary)
        }
    }
}
