import CoreLocation
import MapKit
import SwiftUI
import UIKit

/// 사진 보기에 붙일 날씨 — WeatherKit 은 앱 타깃만 알아서 앱이 시작할 때 꽂는다(확장엔 비어 있다).
public enum PhotoEnrichment {
    public struct Attribution: Equatable, Sendable {
        public let markURL: URL
        public let legalURL: URL
        public init(markURL: URL, legalURL: URL) { self.markURL = markURL; self.legalURL = legalURL }
    }

    public nonisolated(unsafe) static var weather: ((Moment) async -> PlaceWeather?)?
    public nonisolated(unsafe) static var attribution: (() async -> Attribution?)?

    /// WeatherCondition.rawValue → 짧은 우리말. 모르는 값이면 보이지 않는다.
    public static func label(_ condition: String) -> String? { look(condition)?.label }

    /// 저장된 condition 으로 고른다 — WeatherKit symbolName 을 따로 남기지 않는다.
    public static func symbol(_ condition: String, night: Bool) -> String? {
        look(condition).map { night ? $0.night : $0.day }
    }

    /// 단어 고르기(WordPicker)가 쓰는 날씨 — 사진 속 하늘 짐작보다 이게 먼저다.
    public static func wordWeather(_ condition: String) -> Weather? { look(condition)?.word }

    public enum Fall: Equatable, Sendable { case rain, drizzle, snow, storm }

    /// 구름 아래로 떨어지는 것 — 기본 날씨 심볼엔 이 움직임이 없어 직접 그린다(WeatherGlyph).
    public static func fall(_ condition: String) -> Fall? {
        switch look(condition)?.label {
        case "비": .rain
        case "이슬비": .drizzle
        case "눈": .snow
        case "뇌우": .storm
        default: nil
        }
    }

    public static func isNight(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour < 6 || hour >= 19
    }

    /// 하루가 새벽 4시에 닫히므로 00:00~03:59 는 전날 밤의 끝 — 「밤」.
    public static func partOfDay(_ date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 4..<7: "새벽"
        case 7..<11: "아침"
        case 11..<17: "낮"
        case 17..<20: "저녁"
        default: "밤"
        }
    }

    private static func look(_ condition: String) -> (label: String, day: String, night: String, word: Weather)? {
        switch condition {
        case "clear", "mostlyClear", "hot": ("맑음", "sun.max", "moon.stars", .clear)
        case "partlyCloudy": ("구름 조금", "cloud.sun", "cloud.moon", .clear)
        case "mostlyCloudy", "cloudy": ("흐림", "cloud", "cloud", .cloudy)
        case "drizzle": ("이슬비", "cloud.drizzle", "cloud.drizzle", .drizzle)
        case "rain", "heavyRain", "sunShowers", "freezingRain", "freezingDrizzle": ("비", "cloud.rain", "cloud.rain", .rain)
        // 진눈깨비·섞여 내리는 눈은 보이기엔 눈, 단어로는 비 쪽 — 「진눈깨비」는 비일 때만 후보다.
        case "sleet", "wintryMix": ("눈", "cloud.snow", "cloud.snow", .rain)
        case "snow", "flurries", "heavySnow", "sunFlurries", "blowingSnow", "blizzard":
            ("눈", "cloud.snow", "cloud.snow", .snow)
        case "foggy", "haze", "smoky": ("안개", "cloud.fog", "cloud.fog", .fog)
        case "windy", "breezy": ("바람", "wind", "wind", .wind)
        case "thunderstorms", "isolatedThunderstorms", "scatteredThunderstorms", "strongStorms":
            ("뇌우", "cloud.bolt", "cloud.bolt", .rain)
        default: nil
        }
    }
}

/// 보는 중에 날씨·자리가 와서 단어가 가려지면(standingWord nil) 작업을 다시 돌려 그 자리에서 새로 고른다.
private struct PhotoWordTaskKey: Equatable {
    let id: Moment.ID
    let needsWord: Bool
}

private struct DayPhotoLoadKey: Equatable {
    let fileName: String
    let generation: Int
}

struct DayPhotoView: View {
    let momentID: Moment.ID
    let store: DayStore
    /// 「몽돌에서 빼기」를 확인했을 때 — 빼고 옆 사진으로 넘기거나 보기를 닫는 건 부른 쪽이 한다. nil 이면 메뉴를 두지 않는다.
    var onTakeOut: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var attribution: PhotoEnrichment.Attribution?
    @State private var mapOpen = false
    /// 처음 그릴 때 이미 있던 동네·날씨는 그대로 두고, 그 뒤에 도착한 것만 한 글자씩 띄운다.
    @State private var revealArrivals = false
    @State private var pacer = RevealPacer()
    @State private var rejections = WordRejections.shared
    @State private var confirmingTakeOut = false

    private var moment: Moment? { store.moments.first { $0.id == momentID } }
    /// task 가 잡아 둔 값은 옛것이다 — 도중에 붙은 동네·날씨는 여기서 다시 읽는다.
    private var current: Moment? { moment }

    /// 닫히기 전 하루(진행 중인 오늘)의 사진이면 색을 쓰지 않는다 — 로딩 자리·시각 옆 점 모두.
    private func hidesColor(_ m: Moment) -> Bool { Self.hidesColor(m, store: store) }

    static func hidesColor(_ m: Moment, store: DayStore) -> Bool {
        m.dayKey == Moment.dayKey(for: Date()) && !store.isFinished(m.dayKey)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Tone.pure.ignoresSafeArea()
            if let moment {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 60)
                        photo(moment)
                        Spacer().frame(height: 16)
                        words(moment).padding(.horizontal, 26)
                        Spacer().frame(height: 40)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .task(id: DayPhotoLoadKey(fileName: moment.fileName,
                                          generation: ShotImage.generation.value(for: moment.assetID))) {
                    await load(moment)
                }
                .task(id: PhotoWordTaskKey(id: moment.id, needsWord: moment.standingWord() == nil)) {
                    revealArrivals = true
                    async let named: Void = namePlaceIfNeeded(moment)
                    // 단어는 한 번 붙으면 안 바뀐다 — 실제 날씨를 먼저 찾고 고른다(라벨은 그동안 뽑는다).
                    async let weathered: Void = findWeatherIfNeeded(moment)
                    let labels = await labelsForWord(moment)
                    await weathered
                    if let labels { await assignWord(moment, labels: labels) }
                    await named
                    if attribution == nil, current?.place?.weather != nil { attribution = await PhotoEnrichment.attribution?() }
                }
            }
            HStack {
                closeButton
                Spacer()
                if onTakeOut != nil, moment != nil { moreButton }
            }
            .padding(.horizontal, 18).padding(.top, 8)
        }
        .statusBarHidden()
        .accessibilityAction(.escape) { dismiss() }
        .confirmationDialog("몽돌에서 뺄까요?", isPresented: $confirmingTakeOut, titleVisibility: .visible,
                            presenting: moment) { _ in
            Button("빼기", role: .destructive) { onTakeOut?() }
            Button("그대로 둘게요", role: .cancel) {}
        } message: { m in
            Text(Self.takeOutNote(m, store: store))
        }
    }

    /// 닫기 알약의 짝 — 메뉴는 하나뿐이고 길게 눌러 여는 메뉴는 두지 않는다(Tabber).
    private var moreButton: some View {
        Menu {
            Button("몽돌에서 빼기", role: .destructive) { confirmingTakeOut = true }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Tone.secondary)
                .frame(width: Shape2.minTouch, height: Shape2.minTouch)
                .background(.white.opacity(0.12), in: Circle())
        }
        .accessibilityLabel("더 보기")
    }

    /// 사진 앱에 있다고 말할 수 있는 건 assetID·cloudID 가 있을 때뿐 — 다른 기기에만 파일로 있는 사진(remote-)도
    /// 빼면 그 기기가 파일을 지워 다시 못 본다. 안 닫힌 오늘은 조약돌 얘기를 하지 않는다.
    static func takeOutNote(_ m: Moment, store: DayStore) -> String {
        let kept = m.assetID != nil || m.cloudID != nil
            ? "사진 앱에는 그대로 남아요." : "사진 앱에 없는 사진이라 빼면 다시 볼 수 없어요."
        guard !hidesColor(m, store: store) else { return kept }
        if store.moments(on: m.dayKey).count == 1 { return kept + " 이 하루의 조약돌도 사라져요." }
        guard store.pebbleMoments(on: m.dayKey).contains(where: { $0.id == m.id }) else { return kept }
        return kept + " 조약돌은 남은 사진으로 다시 그려져요."
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Text("닫기")
                .font(Face.actionSecondary)
                .foregroundStyle(Tone.primary)
                .padding(.horizontal, 16)
                .frame(minHeight: Shape2.minTouch)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func photo(_ m: Moment) -> some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .transition(.opacity)
            } else {
                (hidesColor(m) ? Tone.veil : Color(hex: m.colorHex)).aspectRatio(3 / 4, contentMode: .fit)
                    .overlay { ProgressView().tint(Tone.secondary) }
            }
        }
        .animation(.easeOut(duration: 0.35), value: image == nil)
        .clipShape(RoundedRectangle(cornerRadius: Shape2.photoWindow, style: .continuous))
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func words(_ m: Moment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let w = m.standingWord() {
                wordLine(m, w)
                Spacer().frame(height: 4)
                RollingLine(w.meaning, delay: 0.12).font(Face.wordMeaning).foregroundStyle(Tone.tertiary)
                Spacer().frame(height: 12)
            }
            meta(m)
            if m.place?.weather != nil, let a = attribution {
                Link(destination: a.legalURL) {
                    AsyncImage(url: a.markURL) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
                        .frame(height: 10)
                        .opacity(0.6)
                }
                .padding(.top, 6)
                .accessibilityLabel("Apple 날씨 데이터 출처")
            }
            if mapOpen, let p = m.place {
                PlaceMap(coordinate: CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude),
                         color: hidesColor(m) ? nil : Color(hex: m.colorHex))
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: Shape2.cardFront, style: .continuous))
                    .padding(.top, 10)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: m.word)
        .animation(.easeOut(duration: 0.25), value: m.place?.name)
        .animation(.easeOut(duration: 0.25), value: m.place?.weather)
    }

    /// 색 점·시각 / 동네 / 날씨 — 좌표가 있으면 한 줄 전체가 지도를 펼치는 버튼이다.
    @ViewBuilder
    private func meta(_ m: Moment) -> some View {
        let line = HStack(spacing: 0) {
            HStack(spacing: 6) {
                if !hidesColor(m) {
                    Circle().fill(Color(hex: m.colorHex)).frame(width: 9, height: 9)
                }
                Text("\(PhotoEnrichment.partOfDay(m.capturedAt))(\(DayGradient.timeText(m.capturedAt)))")
            }
            .fixedSize()
            if let place = m.place?.name {
                RevealPiece(place, reveal: revealArrivals, iconSpacing: 4, pacer: pacer) {
                    Image(systemName: "mappin").imageScale(.small)
                }
                .lineLimit(1)
            }
            if let w = m.place?.weather, let label = PhotoEnrichment.label(w.condition) {
                RevealPiece("\(label) \(Int(w.celsius.rounded()))°", reveal: revealArrivals, iconSpacing: 5, pacer: pacer) {
                    WeatherGlyph(condition: w.condition, night: PhotoEnrichment.isNight(m.capturedAt))
                }
                .fixedSize()
            }
            if m.place != nil {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(mapOpen ? -180 : 0))
                    .padding(.leading, RevealPiece<EmptyView>.gap)
            }
        }
        .font(Face.line)
        .monospacedDigit()
        .foregroundStyle(Tone.secondary)

        if m.place != nil {
            // 글줄은 21pt 라 위아래로 터치 영역만 넓힌다 — 자리는 그대로.
            Button {
                withAnimation(.easeOut(duration: 0.25)) { mapOpen.toggle() }
            } label: {
                line.padding(.vertical, 12).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, -12)
            .accessibilityHint(mapOpen ? "지도를 접어요" : "찍은 곳을 지도로 펼쳐요")
        } else {
            line
        }
    }

    /// 좌표가 있는 사진 — 처음 볼 때 그 시각의 실제 날씨를 한 번 찾아 남긴다(iCloud 로도 간다).
    private func findWeatherIfNeeded(_ m: Moment) async {
        guard m.place != nil, m.place?.weather == nil, let find = PhotoEnrichment.weather else { return }
        guard let w = await find(m), !Task.isCancelled else { return }
        store.setPlaceWeather(m.id, w)
        if attribution == nil { attribution = await PhotoEnrichment.attribution?() }
    }

    /// 좌표만 있는 사진(사진첩·카메라 앱에서 담은 것) — 처음 볼 때 동네 이름을 한 번 찾아 기록에 남긴다(iCloud 로도 간다).
    /// 몽돌로 찍은 사진은 위치를 모르므로 비어 있다.
    private func namePlaceIfNeeded(_ m: Moment) async {
        guard let p = m.place, p.name == nil else { return }
        let marks = try? await CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: p.latitude, longitude: p.longitude), preferredLocale: Locale(identifier: "ko_KR"))
        guard !Task.isCancelled, let mark = marks?.first,
              let name = mark.subLocality ?? mark.locality ?? mark.name else { return }
        store.setPlaceName(m.id, name)
    }

    /// 원본은 iCloud 에서 받느라 오래 걸릴 수 있다 — 목록 썸네일을 먼저 보이고 원본이 오면 바꾼다.
    private func load(_ m: Moment) async {
        async let original = ShotImage.fullWithRetry(m)
        if image == nil {
            if let cached = ShotImage.peek(m, maxPixel: Self.previewPixels) {
                image = cached
            } else if let preview = await ShotImage.warm(m, maxPixel: Self.previewPixels),
                      !Task.isCancelled, image == nil {
                image = preview
            }
        }
        guard let full = await original, !Task.isCancelled else { return }
        image = full
    }

    /// DayMomentsView 사진 카드와 같은 크기 — 거기서 데운 캐시를 그대로 쓴다.
    private static let previewPixels: CGFloat = 600

    /// 단어가 없거나 틀린 사진의 라벨. 저장된 옛 라벨(더 엄격한 기준)은 믿지 않고 다시 보고,
    /// 몇 분 안에 찍은 같은 장면의 라벨을 합친다 — 한 장이 알아봐지면 옆 장도 같이. 저장은 단어와 함께(stampWord).
    /// 맞는 단어가 있으면 nil, Vision 이 실패하면 저장된 라벨(없으면 nil — 다음에 열 때 다시).
    private func labelsForWord(_ m: Moment) async -> [String]? {
        guard m.standingWord() == nil else { return nil }
        let vocabulary = Set(await BundledWordSource().words().flatMap(\.subjects))
        guard var labels = await PhotoLabeler.labels(for: m, vocabulary: vocabulary) else { return m.labels }
        let nearby = store.moments.filter {
            $0.id != m.id && abs($0.capturedAt.timeIntervalSince(m.capturedAt)) <= 300 && !($0.labels ?? []).isEmpty
        }
        for n in nearby.prefix(4) where await PhotoLabeler.sameScene(m, n) {
            labels += (n.labels ?? []).filter { !labels.contains($0) }
        }
        guard !Task.isCancelled else { return nil }
        return labels
    }

    private func assignWord(_ m: Moment, labels: [String]) async {
        let stale = current?.word
        // 틀린 단어를 바꿀 때도 ↻ 로 버린 단어는 빼야 한다.
        guard !Task.isCancelled, current?.standingWord() == nil,
              let pick = await pickWord(for: m, labels: labels, banned: rejections.rejected(m.id)), !Task.isCancelled else { return }
        store.stampWord(m.id, PhotoWord(pick.word), labels: labels, replacing: stale)
    }

    /// 규칙 후보(+그 순간의 말) 안에서 고른다 — 규칙 1순위, 없으면 그 순간의 말.
    private func pickWord(for m: Moment, labels: [String], banned: Set<String> = []) async -> (word: WordEntry, pool: [WordEntry])? {
        let words = await BundledWordSource().words()
        let ctx = PhotoContext(current ?? m, labels: labels)
        let recent = store.recentWordIDs(excluding: m.id).union(rejections.avoided)
        let seed = m.id.uuidString
        let rule = WordPicker.candidates(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned)
        let pool = WordPicker.choices(for: ctx, labels: labels, in: words, excluding: recent, seed: seed, banned: banned)
        guard let first = rule.first ?? pool.first else { return nil }
        return (first, pool)
    }

    /// 단어와 ↻ — ↻는 사진마다 한 번 쓰면 사라진다.
    private func wordLine(_ m: Moment, _ w: PhotoWord) -> some View {
        HStack(alignment: .center, spacing: 4) {
            RollingWord(w.word).font(Face.word).foregroundStyle(Tone.primary)
            if !rejections.hasRejected(m.id), hasAlternative(m, w) {
                RejectWordButton { Task { await reject(m) } }
                    .transition(.opacity)
            }
        }
    }

    /// 바꿀 단어가 없으면 ↻ 를 두지 않는다 — 눌러도 아무 일이 없다(라벨 없는 사진 약 12%, 2026-10-03 교차 검증).
    private func hasAlternative(_ m: Moment, _ w: PhotoWord) -> Bool {
        let labels = m.labels ?? []
        return !WordPicker.choices(for: PhotoContext(m, labels: labels), labels: labels, in: BundledWordSource.cached,
                                   excluding: [], seed: m.id.uuidString, banned: [w.wordID]).isEmpty
    }

    /// 사진마다 한 번 — 다음 후보로 바꾸고, 그때의 라벨·후보를 이 기기에만 남긴다.
    private func reject(_ m: Moment) async {
        guard let old = current?.standingWord(), !rejections.hasRejected(m.id) else { return }
        let labels = current?.labels ?? []
        guard let pick = await pickWord(for: m, labels: labels, banned: [old.wordID]) else { return }
        // 고르는 사이 다른 기기의 단어가 왔으면 바꾸지 않았으니 ↻ 도 쓰지 않은 것으로 둔다.
        guard store.stampWord(m.id, PhotoWord(pick.word), labels: labels, replacing: old) else { return }
        let info = Bundle.main.infoDictionary
        rejections.record(.init(momentID: m.id, wordID: old.wordID, replacedBy: pick.word.id, labels: labels,
                                candidates: pick.pool.map(\.id), partOfDay: PhotoEnrichment.partOfDay(m.capturedAt),
                                weather: current?.place?.weather?.condition,
                                appVersion: "\(info?["CFBundleShortVersionString"] ?? "?")(\(info?["CFBundleVersion"] ?? "?"))",
                                at: Date()))
        Haptics.tickPassed()
    }
}

/// 펼칠 때만 만든다. 지도 로고·법적 고지는 Map 이 붙인다(스냅샷이면 따로 붙여야 한다).
private struct PlaceMap: View {
    let coordinate: CLLocationCoordinate2D
    let color: Color?

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 800, longitudinalMeters: 800)),
            interactionModes: []) {
            Annotation("", coordinate: coordinate, anchor: .center) {
                Circle()
                    .fill(color ?? Tone.secondary)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(.white.opacity(0.88), lineWidth: 1.6))
                    .background(Circle().fill(.white.opacity(0.14)).frame(width: 34, height: 34))
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .environment(\.colorScheme, .dark)
    }
}

/// 늦게 도착한 동네·날씨 한 조각. 앞 조각이 다 뜬 다음 차례로(RevealPacer), 들어갈 자리(앞 간격·아이콘·글자)를
/// 한 번의 곡선으로 벌려 V가 조각마다 한 번만 미끄러지고, 그 안에서 글자가 하나씩 흐릿하게 올라온다(numericText 결).
/// numericText 는 이미 있는 Text 의 내용이 바뀔 때만 돌아서 새로 나타나는 글엔 직접 만든다.
/// 다 뜨면 한 Text 로 돌아가 말줄임·자간이 원래대로 먹는다.
private struct RevealPiece<Icon: View>: View {
    static var gap: CGFloat { 12 }

    let text: String
    let iconSpacing: CGFloat
    let pacer: RevealPacer
    let icon: Icon

    @State private var natural: CGFloat = 0
    @State private var open: Bool
    @State private var iconShown: Bool
    @State private var shown: Int
    @State private var settled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ text: String, reveal: Bool, iconSpacing: CGFloat, pacer: RevealPacer, @ViewBuilder icon: () -> Icon) {
        self.text = text
        self.iconSpacing = iconSpacing
        self.pacer = pacer
        self.icon = icon()
        _open = State(initialValue: !reveal)
        _iconShown = State(initialValue: !reveal)
        _shown = State(initialValue: reveal ? 0 : text.count)
        _settled = State(initialValue: !reveal)
    }

    var body: some View {
        if settled {
            HStack(spacing: iconSpacing) {
                icon
                Text(text)
            }
            .padding(.leading, Self.gap)
        } else {
            HStack(spacing: iconSpacing) {
                icon.modifier(GlyphRise(hidden: !iconShown))
                HStack(spacing: 0) {
                    ForEach(Array(text.enumerated()), id: \.offset) { i, c in
                        Text(String(c)).modifier(GlyphRise(hidden: i >= shown))
                    }
                }
            }
            .padding(.leading, Self.gap)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { natural = $0 }
            .frame(width: open ? natural : 0, alignment: .leading)
            .task { await play() }
        }
    }

    private func play() async {
        guard !settled else { return }
        if open { settle(); return }
        let n = max(text.count, 1)
        let span = min(0.9, 0.4 + 0.07 * Double(n))
        try? await Task.sleep(for: pacer.slot(span))
        guard !Task.isCancelled else { return }
        if reduceMotion { settle(); return }

        let start = ContinuousClock.now
        func at(_ fraction: Double) async { try? await Task.sleep(until: start + .seconds(span * fraction), clock: .continuous) }
        withAnimation(.easeOut(duration: span)) { open = true }
        await at(0.12)
        withAnimation(.easeOut(duration: 0.3)) { iconShown = true }
        for i in 0..<text.count {
            // 자리가 먼저 벌어지고 글자가 뒤따른다 — 안 보이는 글자가 V 위에 겹치지 않게.
            await at(0.25 + 0.7 * Double(i + 1) / Double(n))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { shown = i + 1 }
        }
        await at(1 + 0.3 / span)
        guard !Task.isCancelled else { return }
        settle()
    }

    private func settle() {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            open = true
            iconShown = true
            shown = text.count
            settled = true
        }
    }
}

/// 동네·날씨가 붙어서 도착해도 한 조각씩 — 앞 조각이 다 벌어진 다음에 다음 조각이 벌어진다.
@MainActor
private final class RevealPacer {
    private var free = ContinuousClock.now

    func slot(_ seconds: Double) -> Duration {
        let now = ContinuousClock.now
        let start = max(now, free)
        free = start + .seconds(seconds)
        return start - now
    }
}

private struct GlyphRise: ViewModifier {
    let hidden: Bool

    func body(content: Content) -> some View {
        content
            .opacity(hidden ? 0 : 1)
            .blur(radius: hidden ? 3 : 0)
            .offset(y: hidden ? 6 : 0)
    }
}

/// 비·이슬비·눈·뇌우는 구름 아래로 천천히 떨어지고, 나머지는 기본 심볼 그대로.
/// 동작 줄이기를 켜면 기본 심볼(cloud.rain 등)로 멈춰 있다.
private struct WeatherGlyph: View {
    let condition: String
    let night: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let fall = PhotoEnrichment.fall(condition), !reduceMotion {
            ZStack(alignment: .top) {
                Image(systemName: "cloud").font(.system(size: 11))
                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    Canvas { context, size in
                        Self.draw(fall, at: timeline.date.timeIntervalSinceReferenceDate, in: &context, size: size)
                    }
                }
            }
            .frame(width: 16, height: 15)
        } else if let symbol = PhotoEnrichment.symbol(condition, night: night) {
            Image(systemName: symbol).imageScale(.small)
        }
    }

    private static func draw(_ fall: PhotoEnrichment.Fall, at t: TimeInterval, in context: inout GraphicsContext, size: CGSize) {
        let top: CGFloat = 9.5, bottom = size.height
        let lanes: [CGFloat] = [4.5, 8.3, 12.1]
        let period: Double = switch fall {
        case .rain, .storm: 0.8
        case .drizzle: 1.3
        case .snow: 2.4
        }
        let flash = fall == .storm && t.truncatingRemainder(dividingBy: 3.2) < 0.16

        for (i, x) in lanes.enumerated() {
            if flash && i == 1 { continue }
            let phase = (t / period + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
            let y = top + CGFloat(phase) * (bottom - top - 1.5)
            context.opacity = phase < 0.15 ? phase / 0.15 : phase > 0.7 ? (1 - phase) / 0.3 : 1
            switch fall {
            case .rain, .storm:
                var p = Path()
                p.move(to: CGPoint(x: x + 0.5, y: y))
                p.addLine(to: CGPoint(x: x - 0.3, y: y + 2.4))
                context.stroke(p, with: .foreground, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            case .drizzle:
                context.fill(Path(ellipseIn: CGRect(x: x - 0.75, y: y, width: 1.5, height: 1.5)), with: .foreground)
            case .snow:
                let sway = CGFloat(sin((t * 1.6) + Double(i) * 2.1)) * 0.8
                context.fill(Path(ellipseIn: CGRect(x: x - 0.95 + sway, y: y, width: 1.9, height: 1.9)), with: .foreground)
            }
        }
        if flash {
            context.opacity = 1
            var bolt = Path()
            bolt.move(to: CGPoint(x: 9.2, y: 9))
            bolt.addLine(to: CGPoint(x: 7.4, y: 11.8))
            bolt.addLine(to: CGPoint(x: 9.3, y: 11.8))
            bolt.addLine(to: CGPoint(x: 7.8, y: 14.6))
            context.stroke(bolt, with: .foreground, style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
        }
    }
}

/// ↻ — 처음 한 번은 「이 단어는 아니에요」로 펼쳐졌다가 접혀 무엇인지 알려 준다. 화면 낭독기는 늘 그 말로 읽는다.
private struct RejectWordButton: View {
    let action: () -> Void
    @AppStorage("didLearnWordReject") private var learned = false
    @State private var expanded = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .light))
                if expanded {
                    Text("이 단어는 아니에요").font(Face.caption).fixedSize()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            // 평소엔 가장 옅게(선 단계) — 단어보다 튀지 않게(Tabber). 처음 펼칠 때만 읽히는 밝기.
            .foregroundStyle(expanded ? Tone.tertiary : Tone.hairline)
            .padding(.horizontal, expanded ? 10 : 0)
            .padding(.vertical, 5)
            .background { if expanded { Capsule().fill(.white.opacity(0.08)) } }
            .frame(minWidth: Shape2.minTouch, minHeight: Shape2.minTouch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -7) // 터치는 44pt, 줄 높이는 단어대로
        .accessibilityLabel("이 단어는 아니에요")
        .task {
            guard !learned else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { expanded = true }
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return } // 다 보기 전에 닫으면 다음에 다시
            withAnimation(.easeInOut(duration: 0.4)) { expanded = false }
            learned = true
        }
    }
}

private enum GlyphMotion { case below, shown, above }

/// numericText 결 — 아래(below)에서 흐릿하게 올라와 제자리(shown)에, 떠날 땐 위(above)로 흐려진다.
private struct GlyphRoll: ViewModifier {
    let motion: GlyphMotion

    func body(content: Content) -> some View {
        content
            .opacity(motion == .shown ? 1 : 0)
            .blur(radius: motion == .shown ? 0 : 3)
            .offset(y: motion == .below ? 8 : motion == .above ? -8 : 0)
    }
}

/// 「아니에요」로 단어가 바뀔 때 — 옛 글자는 위로 한 자씩 빠지고 새 글자는 아래에서 한 자씩 올라온다.
/// 옛·새 단어를 겹쳐 두어 폭이 튀지 않는다.
private struct RollingWord: View {
    let text: String
    @State private var layers: [RollLayer]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ text: String) {
        self.text = text
        _layers = State(initialValue: [RollLayer(id: 0, text: text, entering: false)])
    }

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(layers) { layer in
                GlyphRow(text: layer.text, entering: layer.entering, leaving: layer.leaving)
                    .transition(.identity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .onChange(of: text) { _, new in
            guard !reduceMotion else { layers = [RollLayer(id: (layers.last?.id ?? 0) + 1, text: new, entering: false)]; return }
            for i in layers.indices { layers[i].leaving = true }
            layers.append(RollLayer(id: (layers.last?.id ?? 0) + 1, text: new, entering: true))
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                layers.removeAll(where: \.leaving)
            }
        }
    }
}

private struct RollLayer: Identifiable {
    let id: Int
    let text: String
    let entering: Bool
    var leaving = false
}

private struct GlyphRow: View {
    let text: String
    let entering: Bool
    let leaving: Bool
    @State private var shown: Int
    @State private var gone = 0

    init(text: String, entering: Bool, leaving: Bool) {
        self.text = text
        self.entering = entering
        self.leaving = leaving
        _shown = State(initialValue: entering ? 0 : text.count)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { i, c in
                Text(String(c)).modifier(GlyphRoll(motion: i < gone ? .above : i < shown ? .shown : .below))
            }
        }
        .fixedSize()
        .task {
            guard entering else { return }
            try? await Task.sleep(for: .milliseconds(120))
            for i in 0..<text.count {
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.32)) { shown = i + 1 }
                try? await Task.sleep(for: .milliseconds(55))
            }
        }
        .onChange(of: leaving) { _, now in
            guard now else { return }
            Task {
                for i in 0..<text.count {
                    withAnimation(.easeIn(duration: 0.25)) { gone = i + 1 }
                    try? await Task.sleep(for: .milliseconds(40))
                }
            }
        }
    }
}

/// 뜻풀이 — 두 줄로 넘어갈 수 있어 한 자씩이 아니라 문장째 같은 결로 바뀐다(위로 빠지고 아래에서 올라온다).
private struct RollingLine: View {
    let text: String
    let delay: Double
    @State private var layers: [RollLayer]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ text: String, delay: Double) {
        self.text = text
        self.delay = delay
        _layers = State(initialValue: [RollLayer(id: 0, text: text, entering: false)])
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layers) { layer in
                LineLayer(text: layer.text, entering: layer.entering, leaving: layer.leaving, delay: delay)
                    .transition(.identity)
            }
        }
        .onChange(of: text) { _, new in
            guard !reduceMotion else { layers = [RollLayer(id: (layers.last?.id ?? 0) + 1, text: new, entering: false)]; return }
            for i in layers.indices { layers[i].leaving = true }
            layers.append(RollLayer(id: (layers.last?.id ?? 0) + 1, text: new, entering: true))
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                layers.removeAll(where: \.leaving)
            }
        }
    }
}

private struct LineLayer: View {
    let text: String
    let entering: Bool
    let leaving: Bool
    let delay: Double
    @State private var motion: GlyphMotion

    init(text: String, entering: Bool, leaving: Bool, delay: Double) {
        self.text = text
        self.entering = entering
        self.leaving = leaving
        self.delay = delay
        _motion = State(initialValue: entering ? .below : .shown)
    }

    var body: some View {
        Text(text)
            .modifier(GlyphRoll(motion: motion))
            .task {
                guard entering else { return }
                try? await Task.sleep(for: .seconds(0.12 + delay))
                withAnimation(.easeOut(duration: 0.4)) { motion = .shown }
            }
            .onChange(of: leaving) { _, now in
                if now { withAnimation(.easeIn(duration: 0.3)) { motion = .above } }
            }
    }
}
