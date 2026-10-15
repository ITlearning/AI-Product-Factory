import SwiftUI

// MARK: - 모양 — 주운 말을 오늘의 한 장 + 철마다 묶음으로

/// 장면 카드 한 장에 그릴 것.
struct WordCardModel: Identifiable, Equatable {
    var id: String { word }
    let word: String
    let meaning: String?
    let scene: SceneKind
    /// 사진과 함께 주운 말만 — 그 사진의 대표 색(그날이 닫혀 색이 열린 뒤에만).
    let tintHex: String?
    /// 마지막으로 주운 때 「오늘 저녁」.
    let when: String
    /// 「두 번」·「생일」 — 한 번이면 nil.
    let mark: String?
    let picked: PickedWord?

    var accessibilityText: String {
        [word, "\(scene.name) 장면", "\(when)에 주웠어요", mark, meaning].compactMap { $0 }.joined(separator: ". ")
    }
}

struct WordShelf: Equatable {
    struct Shelf: Identifiable, Equatable {
        let id: String
        let title: String
        let cards: [WordCardModel]
    }

    let hero: WordCardModel?
    let seasons: [Shelf]
    /// 서로 다른 말의 수.
    let count: Int

    var isEmpty: Bool { count == 0 }

    static let empty = WordShelf(hero: nil, seasons: [], count: 0)

    /// 가장 최근 말은 오늘의 한 장으로만 — 아래 묶음에 같은 카드를 또 두지 않는다. 빈 철은 머리도 없다.
    static func make(_ words: [PickedWord], entries: [WordEntry] = BundledWordSource.cached,
                     tint: (String) -> String? = { _ in nil }, now: Date = Date()) -> WordShelf {
        var byWord: [String: WordEntry] = [:]
        for e in entries where byWord[e.word] == nil { byWord[e.word] = e }
        let cards = words.map { card($0, entry: byWord[$0.word], tint: tint, now: now) }
        var seasons: [Shelf] = []
        for (w, c) in zip(words, cards).dropFirst() {
            let key = seasonKey(w, entry: byWord[w.word])
            if seasons.last?.id == key.id {
                let last = seasons.removeLast()
                seasons.append(Shelf(id: last.id, title: last.title, cards: last.cards + [c]))
            } else {
                seasons.append(Shelf(id: key.id, title: title(key, now: now), cards: [c]))
            }
        }
        return WordShelf(hero: cards.first, seasons: seasons, count: words.count)
    }

    static func card(_ w: PickedWord, entry: WordEntry?, tint: (String) -> String?, now: Date) -> WordCardModel {
        let scene = entry.map(SceneKind.of) ?? SceneKind.of(PhotoContext.season(month: month(of: w.lastPickedAt)))
        let photo = w.picks.reversed().lazy.compactMap(\.photoID).compactMap(tint).first
        return WordCardModel(word: w.word, meaning: w.meaning, scene: scene, tintHex: photo,
                             when: when(w.lastPickedAt, now: now), mark: mark(w), picked: w)
    }

    /// 지금의 말 카드(빈 상태) — 주운 적 없는 말.
    static func now(_ entry: WordEntry) -> WordCardModel {
        WordCardModel(word: entry.word, meaning: entry.meaning, scene: .of(entry), tintHex: nil,
                      when: "지금", mark: nil, picked: nil)
    }

    static func mark(_ w: PickedWord) -> String? {
        let times = w.count > 1 ? countText(w.count) : nil
        guard w.isBirthday else { return times }
        return times.map { "생일 · \($0)" } ?? "생일"
    }

    static func countText(_ n: Int) -> String {
        let names = [2: "두", 3: "세", 4: "네", 5: "다섯", 6: "여섯", 7: "일곱", 8: "여덟", 9: "아홉", 10: "열"]
        return names[n].map { "\($0) 번" } ?? "\(n)번"
    }

    /// 하루는 새벽 4시에 닫힌다 — 새벽 2시에 주운 말은 「어제 밤」.
    static func when(_ date: Date, now: Date) -> String {
        let part = PhotoEnrichment.partOfDay(date)
        let key = Moment.dayKey(for: date)
        if key == Moment.dayKey(for: now) { return "오늘 \(part)" }
        if key == Moment.dayKey(for: now.addingTimeInterval(-86_400)) { return "어제 \(part)" }
        let p = key.split(separator: "-").compactMap { Int($0) }
        return p.count == 3 ? "\(p[1])월 \(p[2])일 \(part)" : part
    }

    private static func month(of date: Date) -> Int {
        Int(Moment.dayKey(for: date).split(separator: "-")[1]) ?? 1
    }

    private struct SeasonKey { let id: String; let season: Season; let year: Int; let month: Int }

    /// 철 이름은 말 데이터의 계절·달에서, 달은 마지막으로 주운 날에서.
    private static func seasonKey(_ w: PickedWord, entry: WordEntry?) -> SeasonKey {
        let p = Moment.dayKey(for: w.lastPickedAt).split(separator: "-").compactMap { Int($0) }
        let year = p.first ?? 2000, month = p.count > 1 ? p[1] : 1
        let dated = PhotoContext.season(month: month)
        let listed = entry.map { $0.seasons.isEmpty ? $0.months.map(PhotoContext.season(month:)) : $0.seasons } ?? []
        let season = listed.isEmpty || listed.contains(dated) ? dated : listed[0]
        return SeasonKey(id: "\(year)-\(month)-\(season.rawValue)", season: season, year: year, month: month)
    }

    private static func title(_ k: SeasonKey, now: Date) -> String {
        let name = switch k.season {
        case .spring: "봄"
        case .summer: "여름"
        case .autumn: "가을"
        case .winter: "겨울"
        }
        let thisYear = Int(Moment.dayKey(for: now).prefix(4)) ?? k.year
        return k.year == thisYear ? "\(name) · \(k.month)월" : "\(name) · \(k.year)년 \(k.month)월"
    }

    static func source(_ s: PickLine.Source?) -> String {
        switch s {
        case .photo: "사진과 함께"
        case .widget: "위젯에서"
        case .birthday: "생일"
        case .now: "지금의 말"
        case nil: ""
        }
    }
}

// MARK: - 장면 카드

/// 날씨 앱 도시 카드처럼 — 배경은 그 말의 장면, 글자는 SceneArt.textRects 안에만.
struct WordSceneCard: View {
    enum Size { case hero, row }

    static let heroHeight: CGFloat = 232
    static let rowHeight: CGFloat = 96

    let model: WordCardModel
    let size: Size
    var animating = false
    /// 오늘의 한 장 왼쪽 위 — 「오늘 저녁 · 가는 비」.
    var heroLabel: String?

    var body: some View {
        let height = size == .hero ? Self.heroHeight : Self.rowHeight
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                SceneView(model.scene, style: .wash, animating: animating,
                          frameInterval: size == .hero ? SceneView.heroFrameInterval : SceneView.cardFrameInterval,
                          tintHex: model.tintHex)
                switch size {
                case .hero: hero(w: w, h: h)
                case .row: row(w: w, h: h)
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: size == .hero ? 26 : 22, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.accessibilityText)
    }

    // 오늘의 한 장 — 위 라벨(폭 55% × 높이 22%), 말·뜻 덩어리(폭 64%, 높이 50~93%).
    private func hero(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            if let heroLabel {
                Text(heroLabel).font(Face.caption).foregroundStyle(Tone.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: 0.55 * w - 20, alignment: .leading)
                    .padding(.leading, 20).padding(.top, 18)
            }
            VStack(alignment: .leading, spacing: 4) {
                Spacer(minLength: 0)
                Text(model.word).font(Face.wordHero).foregroundStyle(Tone.primary)
                    .lineLimit(1).minimumScaleFactor(0.5)
                if let meaning = model.meaning {
                    Text(meaning).font(Face.wordMeaning).foregroundStyle(Tone.secondary)
                        .lineLimit(2).minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 0.64 * w - 20, height: 0.43 * h, alignment: .bottomLeading)
            .padding(.leading, 20)
            .offset(y: 0.5 * h)
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    // 넓은 카드 — 말(폭 44% × 높이 60%), 날짜(폭 36%, 높이 60~92%), 오른쪽 위 횟수·오른쪽 아래 장면 이름(폭 22%).
    private func row(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Text(model.word).font(Face.wordCard).foregroundStyle(Tone.primary)
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(width: 0.44 * w - 18, height: 0.6 * h - 12, alignment: .topLeading)
                .padding(.leading, 18).padding(.top, 12)
            Text(model.when).font(Face.caption).foregroundStyle(Tone.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: 0.36 * w - 18, height: 0.32 * h, alignment: .bottomLeading)
                .padding(.leading, 18)
                .offset(y: 0.6 * h)
            if let mark = model.mark {
                Text(mark).font(Face.caption).foregroundStyle(Tone.secondary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: 0.22 * w - 16, height: 0.42 * h - 12, alignment: .topTrailing)
                    .padding(.top, 12)
                    .offset(x: 0.78 * w)
            }
            Text(model.scene.name).font(Face.caption).foregroundStyle(Tone.secondary)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: 0.22 * w - 16, height: 0.32 * h, alignment: .bottomTrailing)
                .offset(x: 0.78 * w, y: 0.6 * h)
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }
}

/// 주운 자리에 남는 작은 조약돌.
struct PickedPebble: View {
    var body: some View {
        Ellipse().fill(Tone.secondary).frame(width: 18, height: 13)
            .rotationEffect(.degrees(-8))
            .accessibilityHidden(true)
    }
}

// MARK: - 화면

/// 「말」 칸 — 탭바 세 번째 칸(R5: progress -2). 주운 말이 없으면 지금 밖에 맞는 말 하나 + 줍기(설계 리뷰 2A).
struct WordsView: View {
    let store: DayStore
    /// 이 칸에 정확히 멈췄을 때 — 그때만 기록을 다시 읽고 장면을 움직인다.
    var active: Bool
    var onScrollMinimize: (Bool) -> Void = { _ in }
    var acceptsTaps = true
    var scrollToTop = 0

    enum Phase: Equatable { case loading, failed, ready }

    @State private var phase: Phase = .loading
    @State private var shelf = WordShelf.empty
    @State private var nowWord: WordEntry?
    @State private var nowLooked = false
    @State private var picked = false
    @State private var visible: Set<String> = []
    @State private var opened: WordCardModel?
    @State private var attribution: PhotoEnrichment.Attribution?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var picks: PickedWords? { PickedWords(writer: .app) }

    var body: some View {
        VStack(spacing: 0) {
            WordsHeader(count: shelf.count)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 0).id("top")
                        WordsPage(phase: phase, shelf: shelf, now: nowWord.map(WordShelf.now), nowLooked: nowLooked,
                                  picked: picked, attribution: attribution, active: active, visible: visible,
                                  lazy: true, open: open, pick: pickNow, retry: reload, seen: seen)
                    }
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { old, new in
                    TabBarFold.report(old: old, new: new, to: onScrollMinimize)
                }
                .onChange(of: scrollToTop) { _, _ in
                    withAnimation(.easeOut(duration: 0.35)) { proxy.scrollTo("top", anchor: .top) }
                }
            }
        }
        .background(Tone.base.ignoresSafeArea())
        .task(id: active) {
            guard active else { return }
            reload()
            if attribution == nil { attribution = await PhotoEnrichment.attribution?() }
        }
        .onChange(of: scenePhase) { _, p in if p == .active, active { reload() } }
        .sheet(item: $opened) { card in
            OpenedWordSheet(model: card, remove: { remove(card) })
        }
    }

    private func seen(_ id: String, _ on: Bool) {
        if on { visible.insert(id) } else { visible.remove(id) }
    }

    private func open(_ card: WordCardModel) {
        guard acceptsTaps else { return }
        opened = card
    }

    private func reload() {
        guard let picks else { phase = .failed; return }
        let words = picks.merged()
        shelf = WordShelf.make(words, tint: tint)
        phase = .ready
        if shelf.isEmpty, !nowLooked { Task { await lookNow() } }
    }

    /// 사진 색은 그날이 닫혀 색이 열린 뒤에만 — 색은 자정까지 숨긴다.
    private func tint(_ photoID: String) -> String? {
        guard let id = UUID(uuidString: photoID), let m = store.moment(id),
              !DayPhotoView.hidesColor(m, store: store) else { return nil }
        return m.colorHex
    }

    /// 앱이 가진 위치·날씨로 지금의 말 — 위치가 없으면 서울, 날씨를 못 받으면 계산형 말.
    private func lookNow() async {
        let place = await PlaceFinder.shared.current()
        let weather: PlaceWeather? = if let place { await WeatherLookup.now(at: place) } else { nil }
        let date = Date()
        let ctx = AmbientNow.context(at: date, weather: weather, coordinate: place.map { ($0.latitude, $0.longitude) })
        nowWord = AmbientNow.word(at: date, context: ctx)
        nowLooked = true
        if weather != nil, attribution == nil { attribution = await PhotoEnrichment.attribution?() }
    }

    private func pickNow() {
        guard let entry = nowWord, let picks, !picked else { return }
        if picks.pickedToday(entry.word) { picked = true; return }
        // 디스크에 닿은 뒤에만 「주웠어요」 — 던지면 버튼을 그대로 둔다.
        guard let line = try? picks.pick(entry.word, wordID: entry.id, source: .now) else { return }
        Haptics.snapped()
        if let pick = Telemetry.WordPick(line) { Telemetry.send(.wordPicked(pick)) }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.8)) { picked = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.86)) { reload() }
            picked = false
        }
    }

    private func remove(_ card: WordCardModel) {
        guard let picks, (try? picks.unpick(word: card.word)) != nil else { return }
        opened = nil
        nowLooked = false
        withAnimation(.easeOut(duration: 0.3)) { reload() }
    }
}

struct WordsHeader: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("주운 말").foregroundStyle(Tone.primary)
            if count > 0 { Text("\(count)").monospacedDigit().foregroundStyle(Tone.tertiary) }
        }
        .font(Face.lineCeremony)
        .frame(maxWidth: .infinity, minHeight: Shape2.minTouch)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 스크롤 안의 내용 — 스크롤 밖에서 통째로 그릴 수도 있게 상태를 다 받는다(lazy: false 는 화면 덤프).
struct WordsPage: View {
    let phase: WordsView.Phase
    let shelf: WordShelf
    let now: WordCardModel?
    let nowLooked: Bool
    let picked: Bool
    let attribution: PhotoEnrichment.Attribution?
    let active: Bool
    let visible: Set<String>
    var lazy = true
    var open: (WordCardModel) -> Void = { _ in }
    var pick: () -> Void = {}
    var retry: () -> Void = {}
    var seen: (String, Bool) -> Void = { _, _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch phase {
            case .loading:
                placeholder(WordSceneCard.heroHeight)
            case .failed:
                failed
            case .ready:
                if shelf.isEmpty { empty } else { list }
            }
            attributionMark
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 110)
    }

    private func placeholder(_ height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white.opacity(0.04))
            .frame(height: height)
            .accessibilityHidden(true)
    }

    private var failed: some View {
        VStack(spacing: 12) {
            Text("말을 불러오지 못했어요").font(Face.guide).foregroundStyle(Tone.secondary)
            Button(action: retry) {
                Text("다시").font(Face.actionSecondary).foregroundStyle(Tone.primary)
                    .frame(minWidth: 88, minHeight: Shape2.minTouch)
                    .background(.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    // 빈 상태(2A) — 빈칸·개수 0 없이 지금 밖에 맞는 말 하나와 줍기.
    @ViewBuilder
    private var empty: some View {
        Text("지금 밖에 맞는 말이에요").font(Face.line).foregroundStyle(Tone.secondary)
            .padding(.leading, 2).padding(.bottom, 12)
        if let now {
            WordSceneCard(model: now, size: .hero, animating: active, heroLabel: "지금 · \(now.scene.name)")
                .onScrollVisibilityChange(threshold: 0.05) { seen(now.id, $0) }
            pickRow
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
        } else if nowLooked {
            Text("지금은 맞는 말이 없어요").font(Face.guide).foregroundStyle(Tone.tertiary)
                .frame(maxWidth: .infinity).padding(.top, 40)
        } else {
            placeholder(WordSceneCard.heroHeight)
        }
    }

    // 하루 한 번 — 주우면 버튼 자리에 작은 조약돌만 남는다.
    @ViewBuilder
    private var pickRow: some View {
        if picked {
            HStack(spacing: 8) {
                PickedPebble()
                Text("주웠어요").font(Face.line).foregroundStyle(Tone.secondary)
            }
            .frame(minHeight: Shape2.minTouch)
            .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        } else {
            Button(action: pick) {
                Text("줍기").font(Face.action).foregroundStyle(Tone.primary)
                    .frame(minWidth: 120, minHeight: 48)
                    .background(.white.opacity(0.12), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("주운 말에 담아요")
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var list: some View {
        if let hero = shelf.hero {
            Button { open(hero) } label: {
                WordSceneCard(model: hero, size: .hero, animating: active && visible.contains(hero.id),
                              heroLabel: "\(hero.when) · \(hero.scene.name)")
            }
            .buttonStyle(.plain)
            .accessibilityHint("눌러서 펼쳐요")
            .onScrollVisibilityChange(threshold: 0.05) { seen(hero.id, $0) }
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            .id(hero.id)
        }
        let body = ForEach(shelf.seasons) { s in
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(s.title).font(Face.wordSeason).foregroundStyle(Tone.primary)
                    Text("\(s.cards.count)").font(Face.caption).monospacedDigit().foregroundStyle(Tone.tertiary)
                }
                .padding(.leading, 2)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                ForEach(s.cards) { c in
                    Button { open(c) } label: {
                        WordSceneCard(model: c, size: .row, animating: active && visible.contains(c.id))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("눌러서 펼쳐요")
                    .onScrollVisibilityChange(threshold: 0.05) { seen(c.id, $0) }
                }
            }
            .padding(.top, 30)
        }
        if lazy { LazyVStack(alignment: .leading, spacing: 0) { body } } else { VStack(alignment: .leading, spacing: 0) { body } }
    }

    // R2 — Apple 날씨 로고(다크) + 법적 링크, 「말」 칸 맨 아래.
    @ViewBuilder
    private var attributionMark: some View {
        if let a = attribution {
            Link(destination: a.legalURL) {
                AsyncImage(url: a.markURL) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
                    .frame(height: 10)
                    .opacity(0.6)
                    .frame(maxWidth: .infinity, minHeight: Shape2.minTouch)
            }
            .padding(.top, 28)
            .accessibilityLabel("Apple 날씨 데이터 출처")
        }
    }
}

// MARK: - 펼친 말

struct OpenedWordSheet: View {
    let model: WordCardModel
    let remove: () -> Void

    @State private var confirming = false

    var body: some View {
        ScrollView { content }
        .scrollIndicators(.hidden)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Tone.base)
        .confirmationDialog("주운 말에서 뺄까요?", isPresented: $confirming, titleVisibility: .visible) {
            Button("빼기", role: .destructive) { remove() }
            Button("그대로 두기", role: .cancel) {}
        } message: {
            Text("이 말을 주운 기록이 모두 빠져요")
        }
    }

    var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            WordSceneCard(model: model, size: .hero, animating: true, heroLabel: "\(model.when) · \(model.scene.name)")
                .padding(.top, 24)
            Text(model.word).font(Face.word).foregroundStyle(Tone.primary)
                .padding(.top, 22)
            if let meaning = model.meaning {
                Text(meaning).font(Face.line).foregroundStyle(Tone.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            if let picked = model.picked {
                VStack(alignment: .leading, spacing: 8) {
                    Text("주운 날").font(Face.caption).foregroundStyle(Tone.tertiary)
                    ForEach(picked.picks.reversed(), id: \.id) { p in
                        Text(Self.line(p)).font(Face.caption).monospacedDigit().foregroundStyle(Tone.secondary)
                    }
                }
                .padding(.top, 26)
                .accessibilityElement(children: .combine)
                Button { confirming = true } label: {
                    Text("주운 말에서 빼기").font(Face.guide).foregroundStyle(Tone.tertiary)
                        .frame(maxWidth: .infinity, minHeight: Shape2.minTouch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 36)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }

    static func line(_ p: PickLine) -> String {
        let when = WordShelf.when(p.at, now: Date())
        let from = WordShelf.source(p.source)
        return from.isEmpty ? when : "\(when) · \(from)"
    }
}
