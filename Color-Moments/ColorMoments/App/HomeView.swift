import SwiftUI

struct HomeView: View {
    let store: DayStore

    let showsSwipeHint: Bool

    @Binding var focusDay: String?

    let closures: DayClosures

    // HomeShell 에 알약 스크럽 중임을 알린다 — HomeShell 의 카메라 스와이프가 이 동안 자신을 죽인다.
    @Binding var scrubbing: Bool

    // 하루 상세 시트가 닫힌 뒤 HomeShell 이 증정 확인을 트리거하도록 알린다.
    var onDaySheetDismissed: () -> Void = {}

    // 하루 상세 시트가 떠 있는 동안 true — HomeShell 이 이걸 보고 증정 fullScreenCover 를 미룬다.
    @Binding var daySheetPresented: Bool

    @State private var opened: OpenedDay?
    @State private var topDayKey: String?
    @State private var scrolling = false

    // 스크롤이 멈춘 뒤에도 1.2초는 알약 띠를 살려 둔다 — 손을 떼자마자 사라지면 못 잡는다.
    @State private var lingering = false
    @State private var lingerTask: Task<Void, Never>?

    @State private var pillY: CGFloat = 0
    @State private var scrubMonth: String?

    private struct OpenedDay: Identifiable, Equatable { let id: String }

    private var days: [String] { store.finishedDayKeys }

    private var todayKey: String { Moment.dayKey(for: Date()) }

    // 오늘 사진이 있고 아직 안 닫혔으면 todayLine 대신 진행 중 블록을 보여준다.
    private var todayInProgress: Bool { !store.today.isEmpty && !store.isFinished(todayKey) }

    // 마무리한 오늘은 목록 맨 위에 보통 블록으로 이미 보이므로 todayLine 을 다시 보이지 않는다.
    private var todayClosedWithMoments: Bool { !store.today.isEmpty && store.isFinished(todayKey) }

    private var compactCutoff: String { HomeNavigation.compactCutoff(today: Date()) }

    private var months: [String] { HomeNavigation.months(of: days) }

    private var pillActive: Bool { scrolling || lingering }

    var body: some View {
        ZStack {
            Tone.base.ignoresSafeArea()
            backdrop
            content
            bottomFade
            if pillActive, let label = pillLabel { monthPill(label) }
            if showsSwipeHint { swipeHint }
        }
        .sheet(item: $opened, onDismiss: onDaySheetDismissed) { day in
            DayMomentsView(dayKey: day.id, store: store, closures: closures)
        }
        .onChange(of: opened) { _, value in daySheetPresented = value != nil }
    }

    @ViewBuilder
    private var backdrop: some View {
        if let key = topDayKey ?? days.first {
            DayGradientView(moments: store.pebbleMoments(on: key), axis: .vertical)
                .blur(radius: 60)
                .opacity(0.16)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.45), value: key)
                .allowsHitTesting(false)
        }
    }

    private var content: some View {
        GeometryReader { geo in
            let blockWidth = geo.size.width - 56
            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("몽돌").font(Face.wordmark).foregroundStyle(Tone.primary)
                                .id("top")
                            Spacer().frame(height: 22)
                            if todayInProgress {
                                // 블록을 그릴 때의 dayKey 를 캡처한다 — 탭 시점에 todayKey 를 다시 읽으면
                                // 04시를 넘긴 뒤 눌렀을 때 방금 열린 새 날짜가 열려 버린다.
                                let capturedDayKey = todayKey
                                todayProgressBlock(width: blockWidth)
                                    .contentShape(Rectangle())
                                    .onTapGesture { opened = OpenedDay(id: capturedDayKey) }
                            } else if !todayClosedWithMoments {
                                todayLine
                            }
                            Spacer().frame(height: 38)

                            if days.isEmpty {
                                if !todayInProgress { EmptyDayBlock(width: blockWidth) }
                            } else {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(days.enumerated()), id: \.element) { index, key in
                                        dayRow(key, width: blockWidth)
                                            .contentShape(Rectangle())
                                            .onTapGesture { opened = OpenedDay(id: key) }

                                            .scrollTransition { c, phase in
                                                c.opacity(phase.isIdentity ? 1 : 0.5)
                                                 .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                            }
                                            .onScrollVisibilityChange(threshold: 0.6) { visible in
                                                if visible { topDayKey = key }
                                            }
                                            .id(key)
                                            .padding(.top, index == 0 ? 0 : (key < compactCutoff ? 20 : 64))
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
                        if phase.isScrolling {
                            lingerTask?.cancel()
                            lingering = true
                        } else {
                            scheduleLingerEnd()
                        }
                    }
                    .onChange(of: focusDay) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(days.contains(newValue) ? newValue : "top", anchor: .top)
                        }
                        focusDay = nil
                    }

                    // 오른쪽 가장자리 28pt — 스크롤 중이거나 멈춘 직후에만 손가락을 받는다.
                    // highPriorityGesture 는 이 Color.clear 안에서만 유효해서 HomeShell 의 좌우 스와이프
                    // (다른 뷰에 걸린 simultaneousGesture)를 직접 이기지 못한다. 카메라가 같이 안 열리는 건
                    // scrubbing 을 HomeShell 에 바인딩으로 알려서 그동안 swipe 쪽이 스스로 드래그를 무시하기 때문.
                    Color.clear
                        .frame(width: 28)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in scrub(to: v.location.y, height: geo.size.height, proxy: proxy) }
                                .onEnded { _ in endScrub() }
                        )
                        .allowsHitTesting(pillActive)
                }
            }
        }
    }

    private func scrub(to y: CGFloat, height: CGFloat, proxy: ScrollViewProxy) {
        guard !months.isEmpty else { return }
        scrubbing = true
        lingerTask?.cancel()
        lingering = true
        pillY = min(max(y, 20), max(20, height - 40))

        let fraction = height > 0 ? y / height : 0
        let index = HomeNavigation.monthIndex(fraction: fraction, count: months.count)
        let month = months[index]
        guard month != scrubMonth else { return }
        scrubMonth = month
        if let key = days.first(where: { $0.hasPrefix(month) }) {
            Haptics.tickPassed()
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(key, anchor: .top)
            }
        }
    }

    private func endScrub() {
        scrubbing = false
        scrubMonth = nil
        scheduleLingerEnd()
    }

    private func scheduleLingerEnd() {
        lingerTask?.cancel()
        lingerTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            lingering = false
        }
    }

    @ViewBuilder
    private func dayRow(_ key: String, width: CGFloat) -> some View {
        if key < compactCutoff {
            CompactDayRow(pebbleMoments: store.pebbleMoments(on: key), moments: store.moments(on: key))
        } else {
            DayBlock(moments: store.moments(on: key), pebbleMoments: store.pebbleMoments(on: key), width: width)
        }
    }

    private func todayProgressBlock(width: CGFloat) -> some View {
        // pebbleMoments 를 비워 넘긴다 — 이름도 안 뜨고 조약돌 자리도 점선으로 그려진다(DayBlock sealed: false).
        DayBlock(moments: store.today, pebbleMoments: [], width: width, sealed: false)
    }

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

    private var monthLabel: String? {
        guard let key = topDayKey, key.count >= 7 else { return nil }
        return formattedMonth(String(key.prefix(7)))
    }

    private var pillLabel: String? {
        if scrubbing, let scrubMonth { return formattedMonth(scrubMonth) }
        return monthLabel
    }

    private func formattedMonth(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count >= 2 else { return month }
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
        .padding(.top, scrubbing ? pillY : 120)
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    private var swipeHint: some View {

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
                DashedPebble(height: 84 * k)
                    .offset(x: 272 * k, y: 300 * k)
            }
            .frame(width: width, height: 388 * k, alignment: .topLeading)
            Spacer().frame(height: 26 * k)
            Text("오늘 담은 것은 자정에 조약돌이 돼요")
                .font(Face.guide).foregroundStyle(Tone.tertiary)
        }
    }
}
