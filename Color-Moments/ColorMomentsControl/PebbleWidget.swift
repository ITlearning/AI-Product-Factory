import SwiftUI
import WidgetKit

struct PebbleEntry: TimelineEntry {
    let date: Date
    let state: WidgetSnapshot.State
}

struct PebbleProvider: TimelineProvider {
    func placeholder(in context: Context) -> PebbleEntry {
        PebbleEntry(date: Date(), state: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (PebbleEntry) -> Void) {
        let now = Date()
        let entry = WidgetSnapshot.read().entries(now: now).first
        completion(PebbleEntry(date: now, state: entry?.state ?? .empty))
    }

    // 앱이 증정·담김·전환 때마다 reload 하므로 스스로 다시 묻지 않는다.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PebbleEntry>) -> Void) {
        let entries = WidgetSnapshot.read().entries(now: Date()).map { PebbleEntry(date: $0.date, state: $0.state) }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct PebbleWidgetView: View {
    let entry: PebbleEntry

    private static let pebbleHeight: CGFloat = 66
    // 도착한 돌은 색을 가린다 — 실루엣만 그날 것으로, 색은 중성 회색 한 점.
    private static let hiddenHex = "#3A3B3F"

    var body: some View {
        VStack(spacing: 6) {
            switch entry.state {
            case .pebble(let latest):
                PebbleView(moments: latest.moments, height: Self.pebbleHeight)
                VStack(spacing: 2) {
                    if let name = latest.name {
                        Text(name).font(Face.nameCompact).foregroundStyle(Tone.primary).lineLimit(1)
                    }
                    Text(latest.dateText).font(Face.caption).foregroundStyle(Tone.tertiary).monospacedDigit()
                }
            case .arriving(let dayKey):
                PebbleView(moments: Self.hidden(dayKey), height: Self.pebbleHeight)
                Text("도착했어요").font(Face.guide).foregroundStyle(Tone.secondary)
            case .empty:
                DashedPebble(height: Self.pebbleHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Tone.base, for: .widget)
    }

    private static func hidden(_ dayKey: String) -> [Moment] {
        let noon = Moment.sealDate(for: dayKey)?.addingTimeInterval(-16 * 3600) ?? Date()
        return [Moment(capturedAt: noon, colorHex: hiddenHex, fileName: "", source: .app)]
    }
}

struct PebbleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.itlearning.colormoments.pebble-widget", provider: PebbleProvider()) { entry in
            PebbleWidgetView(entry: entry)
        }
        .configurationDisplayName("몽돌")
        .description("마지막으로 받은 조약돌")
        .supportedFamilies([.systemSmall])
    }
}
