import CoreLocation
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
    public static func label(_ condition: String) -> String? {
        switch condition {
        case "clear", "mostlyClear", "hot": "맑음"
        case "partlyCloudy": "구름 조금"
        case "mostlyCloudy", "cloudy": "흐림"
        case "drizzle": "이슬비"
        case "rain", "heavyRain", "sunShowers", "freezingRain", "freezingDrizzle": "비"
        case "snow", "flurries", "heavySnow", "sleet", "sunFlurries", "wintryMix", "blowingSnow", "blizzard": "눈"
        case "foggy", "haze", "smoky": "안개"
        case "windy", "breezy": "바람"
        case "thunderstorms", "isolatedThunderstorms", "scatteredThunderstorms", "strongStorms": "뇌우"
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
    // 받은 하루일 때만 호출부가 넘긴다 — ImageRenderer/ShareLink 는 앱 타깃 전용.
    var makeShareSheet: (() -> AnyView)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var sharing = false
    @State private var attribution: PhotoEnrichment.Attribution?

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
                    await assignWordIfNeeded(moment)
                    await namePlaceIfNeeded(moment)
                    await findWeatherIfNeeded(moment)
                    if attribution == nil, moment.place?.weather != nil { attribution = await PhotoEnrichment.attribution?() }
                }
            }
            HStack {
                closeButton
                Spacer()
                shareButton
            }
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
    private var shareButton: some View {
        if let makeShareSheet {
            Button { sharing = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Tone.secondary)
                    .frame(width: Shape2.minTouch, height: Shape2.minTouch)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $sharing) { makeShareSheet() }
        }
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
            HStack(spacing: 6) {
                if !hidesColor(m) {
                    Circle().fill(Color(hex: m.colorHex)).frame(width: 9, height: 9)
                }
                Text(DayGradient.timeText(m.capturedAt))
                    .font(Face.wordMeta).monospacedDigit()
                    .foregroundStyle(Tone.tertiary)
                if let place = m.place?.name {
                    Text("·  \(place)")
                        .font(Face.wordMeta)
                        .foregroundStyle(Tone.tertiary)
                        .lineLimit(1)
                        .transition(.opacity)
                }
                if let w = m.place?.weather, let label = PhotoEnrichment.label(w.condition) {
                    Text("·  \(label) \(Int(w.celsius.rounded()))°")
                        .font(Face.wordMeta).monospacedDigit()
                        .foregroundStyle(Tone.tertiary)
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
            if m.place?.weather != nil, let a = attribution {
                Link(destination: a.legalURL) {
                    AsyncImage(url: a.markURL) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
                        .frame(height: 10)
                        .opacity(0.6)
                }
                .padding(.top, 6)
                .accessibilityLabel("Apple 날씨 데이터 출처")
            }
        }
        .animation(.easeOut(duration: 0.25), value: m.word)
        .animation(.easeOut(duration: 0.25), value: m.place?.name)
        .animation(.easeOut(duration: 0.25), value: m.place?.weather)
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
