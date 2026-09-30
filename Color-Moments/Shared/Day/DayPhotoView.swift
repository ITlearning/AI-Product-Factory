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

    private static func look(_ condition: String) -> (label: String, day: String, night: String)? {
        switch condition {
        case "clear", "mostlyClear", "hot": ("맑음", "sun.max", "moon.stars")
        case "partlyCloudy": ("구름 조금", "cloud.sun", "cloud.moon")
        case "mostlyCloudy", "cloudy": ("흐림", "cloud", "cloud")
        case "drizzle": ("이슬비", "cloud.drizzle", "cloud.drizzle")
        case "rain", "heavyRain", "sunShowers", "freezingRain", "freezingDrizzle": ("비", "cloud.rain", "cloud.rain")
        case "snow", "flurries", "heavySnow", "sleet", "sunFlurries", "wintryMix", "blowingSnow", "blizzard":
            ("눈", "cloud.snow", "cloud.snow")
        case "foggy", "haze", "smoky": ("안개", "cloud.fog", "cloud.fog")
        case "windy", "breezy": ("바람", "wind", "wind")
        case "thunderstorms", "isolatedThunderstorms", "scatteredThunderstorms", "strongStorms":
            ("뇌우", "cloud.bolt", "cloud.bolt")
        default: nil
        }
    }
}

private struct DayPhotoLoadKey: Equatable {
    let fileName: String
    let generation: Int
}

struct DayPhotoView: View {
    let momentID: Moment.ID
    let store: DayStore

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var attribution: PhotoEnrichment.Attribution?
    @State private var mapOpen = false
    /// 처음 그릴 때 이미 있던 동네·날씨는 그대로 두고, 그 뒤에 도착한 것만 한 글자씩 띄운다.
    @State private var revealArrivals = false

    private var moment: Moment? { store.moments.first { $0.id == momentID } }

    /// 닫히기 전 하루(진행 중인 오늘)의 사진이면 색을 쓰지 않는다 — 로딩 자리·시각 옆 점 모두.
    private func hidesColor(_ m: Moment) -> Bool {
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
                .task(id: moment.id) {
                    revealArrivals = true
                    await assignWordIfNeeded(moment)
                    await namePlaceIfNeeded(moment)
                    await findWeatherIfNeeded(moment)
                    if attribution == nil, moment.place?.weather != nil { attribution = await PhotoEnrichment.attribution?() }
                }
            }
            closeButton
                .padding(.horizontal, 18).padding(.top, 8)
        }
        .statusBarHidden()
        .accessibilityAction(.escape) { dismiss() }
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
            if let w = m.word {
                Text(w.word).font(Face.word).foregroundStyle(Tone.primary)
                Spacer().frame(height: 4)
                Text(w.meaning).font(Face.wordMeaning).foregroundStyle(Tone.tertiary)
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
        let line = HStack(spacing: 12) {
            HStack(spacing: 6) {
                if !hidesColor(m) {
                    Circle().fill(Color(hex: m.colorHex)).frame(width: 9, height: 9)
                }
                Text("\(PhotoEnrichment.partOfDay(m.capturedAt))(\(DayGradient.timeText(m.capturedAt)))")
            }
            .fixedSize()
            if let place = m.place?.name {
                HStack(spacing: 4) {
                    Image(systemName: "mappin").imageScale(.small)
                    RevealText(place, reveal: revealArrivals).lineLimit(1)
                }
                .transition(.glyph)
            }
            if let w = m.place?.weather, let label = PhotoEnrichment.label(w.condition) {
                HStack(spacing: 5) {
                    if let symbol = PhotoEnrichment.symbol(w.condition, night: PhotoEnrichment.isNight(m.capturedAt)) {
                        Image(systemName: symbol).imageScale(.small)
                    }
                    RevealText("\(label) \(Int(w.celsius.rounded()))°", reveal: revealArrivals)
                }
                .fixedSize()
                .transition(.glyph)
            }
            if m.place != nil {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(mapOpen ? -180 : 0))
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

    private func assignWordIfNeeded(_ m: Moment) async {
        guard m.word == nil else { return }
        var labels = m.labels
        if labels == nil {
            labels = await PhotoLabeler.labels(for: m)
            guard let labels else { return } // Vision failed — retry next open, don't stamp a bad guess
            store.setLabels(m.id, labels)
        }
        let seen = Set(labels ?? [])
        let words = await BundledWordSource().words()
        let ctx = PhotoContext(date: m.capturedAt, weather: Weather.inferred(from: seen))
        guard let pw = WordPicker.photoWord(for: ctx, labels: seen, in: words,
                                            excluding: store.recentWordIDs(excluding: m.id), seed: m.id.uuidString) else { return }
        store.assignWord(m.id, pw)
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

/// 늦게 도착한 글을 한 글자씩 — 글자마다 흐릿하게 아래에서 올라온다(numericText 결).
/// numericText 는 이미 있는 Text 의 내용이 바뀔 때만 돌아서, 새로 나타나는 글엔 직접 만든다.
/// 다 뜨면 한 Text 로 돌아가 말줄임·자간이 원래대로 먹는다.
private struct RevealText: View {
    let text: String
    @State private var shown: Int
    @State private var settled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ text: String, reveal: Bool) {
        self.text = text
        _shown = State(initialValue: reveal ? 0 : text.count)
        _settled = State(initialValue: !reveal)
    }

    var body: some View {
        Group {
            if settled {
                Text(text)
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(text.prefix(shown).enumerated()), id: \.offset) { _, c in
                        Text(String(c)).transition(.glyph)
                    }
                }
            }
        }
        .task(id: text) {
            guard !settled else { return }
            if !reduceMotion {
                while shown < text.count {
                    try? await Task.sleep(for: .milliseconds(45))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.3)) { shown += 1 }
                }
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
            }
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { settled = true }
        }
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

private extension AnyTransition {
    static var glyph: AnyTransition { .modifier(active: GlyphRise(hidden: true), identity: GlyphRise(hidden: false)) }
}
