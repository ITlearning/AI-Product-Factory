import AppIntents
import SwiftUI
import WidgetKit

// 화면 문구는 widget-words.json — 여기 한글은 시스템이 그리는 이름(위젯 편집·단축어)뿐이다.

struct WordLookEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "모양"
    static var defaultQuery = WordLookQuery()

    let id: String

    init(_ style: SceneStyle) { id = style.rawValue }

    var style: SceneStyle { SceneStyle(rawValue: id) ?? .wash }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(WordWidgetText.cached?.looks[id] ?? id)")
    }
}

struct WordLookQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WordLookEntity] {
        identifiers.compactMap(SceneStyle.init(rawValue:)).map(WordLookEntity.init)
    }

    func suggestedEntities() async throws -> [WordLookEntity] { SceneStyle.allCases.map(WordLookEntity.init) }

    /// 새로 붙이는 위젯은 앱 설정 「위젯 모양」을 따른다.
    func defaultResult() async -> WordLookEntity? { WordLookEntity(WordWidgetLook.current) }
}

struct WordWidgetConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "밀려온 말"

    @Parameter(title: "모양")
    var look: WordLookEntity?

    init() {}
}

/// 위젯에서 줍기 — 디스크에 닿은 뒤에만 「주웠어요」. 같은 말은 하루(새벽 4시 경계)에 한 번.
struct PickWordIntent: AppIntent {
    static var title: LocalizedStringResource = "말 줍기"
    static var isDiscoverable = false

    @Parameter(title: "말") var word: String
    @Parameter(title: "id") var wordID: String

    init() {}

    init(word: String, wordID: String) {
        self.word = word
        self.wordID = wordID
    }

    enum Failure: Error { case noContainer }

    func perform() async throws -> some IntentResult {
        guard let picks = PickedWords(writer: .widget) else { throw Failure.noContainer }
        if !picks.pickedToday(word) {
            _ = try picks.pick(word, wordID: wordID, source: .widget)
            JustPicked(word: word, at: Date()).write()
        }
        return .result()
    }
}

// MARK: - 타임라인

struct WordTimelineEntry: TimelineEntry {
    let date: Date
    let model: WordWidgetModel
    var style: SceneStyle = .wash
}

enum WordWidgetFeed {
    /// fetches — 실제 타임라인일 때만 예보를 받는다(미리보기·자리 표시는 캐시만).
    static func models(now: Date = Date(), fetches: Bool) async -> [WordWidgetModel] {
        let store = AmbientStore()
        var forecast = store?.forecast()
        if fetches, let store { forecast = await AmbientNow.refresh(now: now, store: store, source: WeatherKitForecast()) }
        let picks = PickedWords(writer: .widget)?.livePicks() ?? []
        return WordWidgetTimeline.models(now: now, forecast: forecast, place: store?.place(), picks: picks,
                                         justPicked: JustPicked.read())
    }

    static func timeline(_ models: [WordWidgetModel], style: SceneStyle, now: Date) -> Timeline<WordTimelineEntry> {
        Timeline(entries: models.map { WordTimelineEntry(date: $0.date, model: $0, style: style) },
                 policy: .after(now.addingTimeInterval(WordWidgetTimeline.reloadAfter)))
    }
}

struct WordWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WordTimelineEntry {
        WordTimelineEntry(date: Date(), model: .blank(Date()), style: WordWidgetLook.current)
    }

    func snapshot(for configuration: WordWidgetConfig, in context: Context) async -> WordTimelineEntry {
        let now = Date()
        let model = await WordWidgetFeed.models(now: now, fetches: false).first ?? .blank(now)
        return WordTimelineEntry(date: now, model: model, style: configuration.look?.style ?? WordWidgetLook.current)
    }

    func timeline(for configuration: WordWidgetConfig, in context: Context) async -> Timeline<WordTimelineEntry> {
        let now = Date()
        if !context.isPreview { WordWidgetAdded.mark(now: now) }
        let models = await WordWidgetFeed.models(now: now, fetches: !context.isPreview)
        return WordWidgetFeed.timeline(models, style: configuration.look?.style ?? WordWidgetLook.current, now: now)
    }
}

struct WordLockProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordTimelineEntry {
        WordTimelineEntry(date: Date(), model: .blank(Date()), style: .print)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordTimelineEntry) -> Void) {
        Task {
            let now = Date()
            let model = await WordWidgetFeed.models(now: now, fetches: false).first ?? .blank(now)
            completion(WordTimelineEntry(date: now, model: model, style: .print))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordTimelineEntry>) -> Void) {
        Task {
            let now = Date()
            if !context.isPreview { WordWidgetAdded.mark(now: now) }
            let models = await WordWidgetFeed.models(now: now, fetches: !context.isPreview)
            completion(WordWidgetFeed.timeline(models, style: .print, now: now))
        }
    }
}

// MARK: - 위젯

struct WordWidgetView: View {
    let entry: WordTimelineEntry

    var body: some View {
        let text = WordWidgetText.cached
        WordWidgetSmall(model: entry.model, style: entry.style, text: text, drawsBackground: false) { m in
            if let word = m.word, let id = m.wordID {
                Button(intent: PickWordIntent(word: word, wordID: id)) { WordPickLabel(text?.pick ?? "") }
                    .buttonStyle(.plain)
                    .accessibilityHint(text?.pickHint ?? "")
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: entry.model.pick)
        .containerBackground(for: .widget) { WordWidgetBackground(model: entry.model, style: entry.style) }
        .widgetURL(WordWidgetTimeline.url)
    }
}

struct WordWidget: Widget {
    var body: some WidgetConfiguration {
        let text = WordWidgetText.cached
        return AppIntentConfiguration(kind: WordWidgetTimeline.kind, intent: WordWidgetConfig.self,
                                      provider: WordWidgetProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName(text?.name ?? "")
        .description(text?.description ?? "")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct WordLockView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordTimelineEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline: WordLockInline(model: entry.model)
            case .accessoryCircular: WordLockCircular(model: entry.model)
            default: WordLockRectangular(model: entry.model)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.model.accessibilityText(WordWidgetText.cached) ?? "")
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(WordWidgetTimeline.url)
    }
}

struct WordLockWidget: Widget {
    var body: some WidgetConfiguration {
        let text = WordWidgetText.cached
        return StaticConfiguration(kind: WordWidgetTimeline.lockKind, provider: WordLockProvider()) { entry in
            WordLockView(entry: entry)
        }
        .configurationDisplayName(text?.name ?? "")
        .description(text?.lockDescription ?? "")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}
