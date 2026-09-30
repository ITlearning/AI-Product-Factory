import SwiftUI

struct HomeView: View {
    let store: DayStore

    let gifts: GiftLog

    let showsSwipeHint: Bool

    @Binding var focusDay: String?

    let closures: DayClosures

    // HomeShell 에 알약 스크럽 중임을 알린다 — HomeShell 의 카메라 스와이프가 이 동안 자신을 죽인다.
    @Binding var scrubbing: Bool

    // 하루 상세 시트가 닫힌 뒤 HomeShell 이 증정 확인을 트리거하도록 알린다.
    var onDaySheetDismissed: () -> Void = {}

    // 하루 상세 시트가 떠 있는 동안 true — HomeShell 이 이걸 보고 증정 fullScreenCover 를 미룬다.
    @Binding var daySheetPresented: Bool

    // 카드 시트·한 줌 전체 화면이 떠 있는 동안 true — 여는 순간 올리고 onDismiss 에서만 내린다(증정 가드).
    @Binding var keepsakePresented: Bool

    // 하루를 마무리할 때(closures.close) HomeShell 이 아침 도착 소식 예약을 다시 맞추도록 알린다.
    var onDayClosed: () -> Void = {}

    // 빈 첫 화면의 "지난 며칠 담기" 제안을 누르면 HomeShell 이 기존 사진첩 담기 화면을 띄운다.
    var onRequestLibraryPicker: () -> Void = {}

    // 카메라·사진첩·시트가 홈을 가리는 동안 true — 새 줄 등장 연출을 걷힐 때까지 미룬다.
    var holdsArrivals: Bool = false

    /// 밖(온보딩 끝)에서 이 하루를 열어 달라고 할 때 — 열고 나면 nil 로 되돌린다.
    var openDay: Binding<String?> = .constant(nil)

    // 기록이 한 번이라도 생기면 true — 그 뒤엔 사진첩 제안 문구를 다시 보이지 않는다.
    @AppStorage("didOfferLibraryOnboarding") private var didOfferLibraryOnboarding = false

    @State private var opened: OpenedDay?
    @State private var sharingDayKey: SharingDay?
    @State private var openedMonth: OpenedMonth?
    @State private var topDayKey: String?
    @State private var blend = HomeBackdropBlend()
    @State private var scrolling = false

    // 스크롤이 멈춘 뒤에도 1.2초는 알약 띠를 살려 둔다 — 손을 떼자마자 사라지면 못 잡는다.
    @State private var lingering = false
    @State private var lingerTask: Task<Void, Never>?
    // 취소된 스크럽은 onEnded 가 없다 — scrubbing 이 남으면 HomeShell 의 좌우 스와이프가 계속 무시된다.
    @GestureState private var scrubHeld = false

    @State private var arrivals = Arrivals()

    @State private var pillY: CGFloat = 0
    @State private var scrubMonth: String?

    private struct OpenedDay: Identifiable, Equatable { let id: String }
    private struct SharingDay: Identifiable { let id: String }
    private struct OpenedMonth: Identifiable { let id: String }

    // 받지 않은 하루는 작년 이맘때·한 달 한 줌 어디에도 들어가지 않는다 — floor 판정은 GiftLog 하나뿐.
    private var home: HomeSummary { store.home(gifts: gifts) }

    private var days: [String] { home.days }

    private var todayKey: String { Moment.dayKey(for: Date()) }

    // 오늘 사진이 있고 아직 안 닫혔으면 todayLine 대신 진행 중 블록을 보여준다.
    private var todayInProgress: Bool { !store.today.isEmpty && !store.isFinished(todayKey) }

    // 마무리한 오늘은 목록 맨 위에 보통 블록으로 이미 보이므로 todayLine 을 다시 보이지 않는다.
    private var todayClosedWithMoments: Bool { !store.today.isEmpty && store.isFinished(todayKey) }

    private var compactCutoff: String { HomeNavigation.compactCutoff(today: Date()) }

    private var months: [String] { home.months }

    private var pillActive: Bool { scrolling || lingering }

    private var lastYearDayKey: String? { home.lastYearDayKey }

    private var handfulMonths: Set<String> { home.handfulMonths }

    private static let progressID = "progress"

    // 화면 위→아래 순서의 줄 id — 등장 연출이 새로 생긴 줄을 가려내는 기준.
    private var appearanceIDs: [String] {
        todayInProgress ? [Self.progressID] + home.appearanceIDs : home.appearanceIDs
    }

    private func noteArrivals(_ ids: [String]) {
        schedule(arrivals.update(ids: ids, loaded: store.isLoaded, held: holdsArrivals))
    }

    private func schedule(_ animated: [String]) {
        guard !animated.isEmpty else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Arrivals.sweepAfter * 1_000_000_000))
            arrivals.finish(animated)
        }
    }

    private func arrivalPhase(_ id: String) -> Arrivals.Phase { arrivals.phase(id) }

    private func giftedPebbleGroups(forMonth month: String) -> [[Moment]] {
        home.giftedDays.filter { $0.hasPrefix(month) }.map { store.pebbleMoments(on: $0) }
    }

    var body: some View {
        ZStack {
            Tone.base.ignoresSafeArea()
            backdrop
            content
            bottomFade
            if pillActive, let label = pillLabel { monthPill(label) }
            edgeHints
        }
        .sheet(item: $opened, onDismiss: {
            // opened 가 nil 이 되는 건 닫힘 애니메이션 시작 — 끝난 뒤(onDismiss)에만 가드를 푼다.
            daySheetPresented = false
            onDaySheetDismissed()
        }) { day in
            DayMomentsView(dayKey: day.id, store: store, closures: closures,
                           isGifted: gifts.isGifted, onClosed: onDayClosed,
                           makeShareSheet: { key, viewing in
                               AnyView(KeepsakeShareSheet(dayKey: key, store: store, viewingID: viewing))
                           })
        }
        .sheet(item: $sharingDayKey, onDismiss: keepsakeDismissed) { day in
            KeepsakeShareSheet(dayKey: day.id, store: store)
        }
        .fullScreenCover(item: $openedMonth, onDismiss: keepsakeDismissed) { month in
            HandfulView(month: month.id, pebbleGroups: giftedPebbleGroups(forMonth: month.id),
                        today: todayKey,
                        makeShareSheet: {
                            AnyView(HandfulShareSheet(month: month.id, today: todayKey,
                                                      pebbleGroups: giftedPebbleGroups(forMonth: month.id)))
                        })
        }
        .onChange(of: opened) { _, value in if value != nil { daySheetPresented = true } }
        .onChange(of: sharingDayKey?.id) { _, value in if value != nil { keepsakePresented = true } }
        .onChange(of: openedMonth?.id) { _, value in if value != nil { keepsakePresented = true } }
        .task { if !store.moments.isEmpty { didOfferLibraryOnboarding = true } }
        .onAppear { noteArrivals(appearanceIDs) }
        .onChange(of: appearanceIDs) { _, ids in noteArrivals(ids) }
        .onChange(of: store.isLoaded) { _, _ in noteArrivals(appearanceIDs) }
        .onChange(of: holdsArrivals) { _, held in
            if !held { schedule(arrivals.release(order: appearanceIDs)) }
        }
        .onChange(of: store.moments.isEmpty) { _, isEmpty in
            if !isEmpty { didOfferLibraryOnboarding = true }
        }
        .onChange(of: openDay.wrappedValue) { _, key in
            guard let key else { return }
            openDay.wrappedValue = nil
            focusDay = key
            open(key)
        }
    }

    private func open(_ key: String) {
        daySheetPresented = true
        opened = OpenedDay(id: key)
    }

    private func keepsakeDismissed() {
        keepsakePresented = false
        onDaySheetDismissed()
    }

    // 그 달 첫 하루(목록 순서)에 한 줌 머리글이 붙어 있으면 머리글로 스크롤한다 — 하루로 가면 머리글이 위로 가려진다.
    private func scrollID(for key: String) -> String {
        let month = String(key.prefix(7))
        guard handfulMonths.contains(month), home.firstDayOfMonth[month] == key else { return key }
        return "month-\(month)"
    }

    private var backdrop: some View {
        HomeBackdrop(blend: blend, store: store, fallback: days.first)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onChange(of: days, initial: true) { _, keys in blend.setOrder(keys) }
    }

    private var content: some View {
        GeometryReader { geo in
            let blockWidth = max(0, geo.size.width - 56)  // 첫 배치에서 geo 가 0 이면 음수 프레임이 된다
            let _ = blend.setReference(geo.size.height * 0.4)
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
                                    .arrival(arrivalPhase(Self.progressID)) { arrivals.finish([Self.progressID]) }
                                    .contentShape(Rectangle())
                                    .onTapGesture { open(capturedDayKey) }
                            } else if !todayClosedWithMoments {
                                // 로드 전엔 자리만 잡는다 — 「비어 있어요」가 번쩍 떴다 바뀌지 않게.
                                todayLine.opacity(store.isLoaded ? 1 : 0)
                            }
                            lastYearLine
                            Spacer().frame(height: 38)

                            if days.isEmpty {
                                if !todayInProgress && store.isLoaded {
                                    EmptyDayBlock(width: blockWidth)
                                    if !didOfferLibraryOnboarding {
                                        Spacer().frame(height: 20)
                                        libraryOnboardingLine
                                    }
                                }
                            } else {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    // 행 클로저는 LazyVStack 이 늦게 돌린다 — 목록을 인덱스로 다시 읽으면 줄어든 배열에서 트랩난다. 행 모델만 쓴다.
                                    ForEach(home.rows) { row in
                                        let key = row.key, index = row.index, month = row.month
                                        let hasHeader = row.hasHeader
                                        if hasHeader {
                                            // 위 여백 > 아래 여백 — 머리글이 앞 달 마지막 블록의 캡션처럼 붙지 않게.
                                            monthHandfulHeader(month)
                                                .arrival(arrivalPhase("month-\(month)")) { arrivals.finish(["month-\(month)"]) }
                                                .padding(.top, index == 0 ? 0 : 56)
                                                .id("month-\(month)")
                                        }
                                        dayRow(key, width: blockWidth)
                                            .arrival(arrivalPhase(key)) { arrivals.finish([key]) }
                                            .contentShape(Rectangle())
                                            .onTapGesture { open(key) }

                                            .scrollTransition { c, phase in
                                                c.opacity(phase.isIdentity ? 1 : 0.5)
                                                 .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                            }
                                            .onScrollVisibilityChange(threshold: 0.6) { visible in
                                                if visible { topDayKey = key }
                                            }
                                            .id(key)
                                            // 배경 섞기용 — 매 프레임 오지만 HomeView 는 이 값을 읽지 않는다(배경 뷰만 다시 그린다).
                                            .onGeometryChange(for: CGFloat.self) {
                                                $0.frame(in: .scrollView(axis: .vertical)).minY
                                            } action: { blend.report(key, top: $0) }
                                            .onDisappear { blend.forget(key) }
                                            .padding(.top, hasHeader ? 16 : (index == 0 ? 0 : (key < compactCutoff ? 20 : 64)))
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
                            proxy.scrollTo(days.contains(newValue) ? scrollID(for: newValue) : "top", anchor: .top)
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
                                .updating($scrubHeld) { _, held, _ in held = true }
                                .onChanged { v in scrub(to: v.location.y, height: geo.size.height, proxy: proxy) }
                                .onEnded { _ in endScrub() }
                        )
                        .allowsHitTesting(pillActive)
                        .onChange(of: scrubHeld) { _, held in if !held && scrubbing { endScrub() } }
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
        if let key = home.firstDayOfMonth[month] {
            Haptics.tickPassed()
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(scrollID(for: key), anchor: .top)
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
        // 받은 하루만 「카드로 만들기」 — 안 받은 하루는 메뉴 자체를 안 건다(빈 메뉴가 뜨면 안 된다).
        if Keepsake.canMakeCard(dayKey: key, isGifted: gifts.isGifted) {
            dayRowContent(key, width: width)
                .contextMenu {
                    Button {
                        keepsakePresented = true
                        sharingDayKey = SharingDay(id: key)
                    } label: {
                        Label("카드로 만들기", systemImage: "square.and.arrow.up")
                    }
                }
        } else {
            dayRowContent(key, width: width)
        }
    }

    @ViewBuilder
    private func dayRowContent(_ key: String, width: CGFloat) -> some View {
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

    private var libraryOnboardingLine: some View {
        Text("지난 며칠 사진으로 먼저 받아 볼까요?")
            .font(Face.line)
            .foregroundStyle(Tone.secondary)
            .frame(minHeight: Shape2.minTouch, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onRequestLibraryPicker() }
    }

    // 받은 날이 1년 전 ±3일 안에 없으면 아무것도 안 보인다 — 이름만 명조, 나머지는 SF.
    @ViewBuilder
    private var lastYearLine: some View {
        if let key = lastYearDayKey, let named = PebbleNaming.name(for: store.pebbleMoments(on: key)) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 14)
                (Text("작년 이맘때 · ").font(Face.line).foregroundStyle(Tone.secondary)
                    + Text(named.name).font(Face.nameCompact).foregroundStyle(Tone.primary))
                    .frame(minHeight: Shape2.minTouch, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { open(key) }
            }
        }
    }

    private func monthHandfulHeader(_ month: String) -> some View {
        Text(Memories.handfulTitle(month: month, today: todayKey))
            .font(Face.line)
            .foregroundStyle(Tone.secondary)
            .frame(minHeight: Shape2.minTouch, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                keepsakePresented = true
                openedMonth = OpenedMonth(id: month)
            }
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

    /// 양쪽 몸짓 안내 — 온보딩을 거쳐도 모르는 사람이 있어 늘 희미하게 둔다(2026-10-01 Tabber).
    /// 한 번도 쓸어 본 적 없으면 조금 더 또렷하게. 오른쪽은 날짜 알약이 뜨는 동안 비켜 준다.
    private var edgeHints: some View {
        HStack(spacing: 0) {
            edgeHint("쓸면 담기", leading: true)
            Spacer()
            edgeHint("쓸면 모아 보기", leading: false)
                .opacity(pillActive ? 0 : 1)
        }
        .opacity(showsSwipeHint ? 1 : 0.45)
        .animation(.easeOut(duration: 0.25), value: pillActive)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func edgeHint(_ text: String, leading: Bool) -> some View {
        HStack(spacing: 7) {
            if !leading { label(text, degrees: 90) }
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Tone.tertiary)
                .frame(width: 3, height: 34)
            if leading { label(text, degrees: -90) }
        }
        .padding(leading ? .leading : .trailing, 5)
    }

    private func label(_ text: String, degrees: Double) -> some View {
        Text(text)
            .font(Face.caption)
            .foregroundStyle(Tone.tertiary)
            .fixedSize()
            .rotationEffect(.degrees(degrees))
            .frame(width: 12, height: 86)
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
    private var k: CGFloat { max(0, width) / 334 }

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

/// 홈 배경 — 기준선(화면 높이 40%)에 걸린 하루와 다음 하루의 색을, 다음 하루가 기준선에 다가온 만큼 섞는다.
/// 행 위치는 관찰하지 않는 값에만 쌓고, 섞을 두 하루와 비율만 관찰 대상이라 배경 뷰만 다시 그려진다.
@Observable
final class HomeBackdropBlend {
    private(set) var from: String?
    private(set) var to: String?
    private(set) var t: Double = 0

    @ObservationIgnored private var tops: [String: CGFloat] = [:]
    @ObservationIgnored private var index: [String: Int] = [:]
    @ObservationIgnored private var order: [String] = []
    @ObservationIgnored private var reference: CGFloat = 300

    func setOrder(_ keys: [String]) {
        order = keys
        index = Dictionary(keys.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        tops = tops.filter { index[$0.key] != nil }
        recompute()
    }

    func setReference(_ y: CGFloat) {
        guard y > 0, abs(y - reference) > 0.5 else { return }
        reference = y
    }

    func report(_ key: String, top: CGFloat) {
        tops[key] = top
        recompute()
    }

    func forget(_ key: String) {
        tops[key] = nil
    }

    private func recompute() {
        // 기준선 위(또는 걸친)에서 가장 아래에 있는 하루 — 없으면(맨 위) 첫 하루를 그대로.
        var current: (key: String, top: CGFloat, i: Int)?
        for (key, top) in tops where top <= reference {
            guard let i = index[key] else { continue }
            if current == nil || i > current!.i { current = (key, top, i) }
        }
        guard let cur = current else {
            apply(from: order.first, to: nil, t: 0)
            return
        }
        let nextIndex = cur.i + 1
        guard nextIndex < order.count, let nextTop = tops[order[nextIndex]], nextTop > cur.top else {
            apply(from: cur.key, to: nil, t: 0)
            return
        }
        let raw = Double((reference - cur.top) / (nextTop - cur.top))
        let eased = min(1, max(0, raw))
        apply(from: cur.key, to: order[nextIndex], t: eased * eased * (3 - 2 * eased))
    }

    private func apply(from: String?, to: String?, t: Double) {
        if from != self.from { self.from = from }
        if to != self.to { self.to = to }
        // 눈에 안 띌 만큼만 바뀌면 다시 그리지 않는다 — 스크롤 중 매 프레임 들어온다.
        if abs(t - self.t) > 0.004 || (t == 0 && self.t != 0) || (t == 1 && self.t != 1) { self.t = t }
    }
}

/// 배경 두 겹 — 같은 자리에서 불투명도만 바뀐다. 경계에서 from/to 가 넘어가도 그 순간 보이는 색은 같다.
private struct HomeBackdrop: View {
    let blend: HomeBackdropBlend
    let store: DayStore
    let fallback: String?

    var body: some View {
        ZStack {
            if let from = blend.from ?? fallback {
                layer(from).opacity(1 - (blend.to == nil ? 0 : blend.t))
            }
            if let to = blend.to, blend.t > 0 {
                layer(to).opacity(blend.t)
            }
        }
    }

    private func layer(_ key: String) -> some View {
        DayGradientView(moments: store.pebbleMoments(on: key), axis: .vertical)
            .blur(radius: 60)
            .opacity(0.16)
    }
}
