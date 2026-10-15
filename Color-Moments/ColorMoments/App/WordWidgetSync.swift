import Foundation
import UIKit
import WidgetKit

/// 앱 쪽 「밀려온 말」 위젯 일 — 위치·예보를 App Group 에 맞추고, 확장에 없는 계측을 대신 보낸다.
@MainActor
enum WordWidgetSync {

    /// 앱이 열릴 때 — 위치(약 1km)를 남기고 예보를 맞춘 뒤, 바뀌었으면 위젯을 다시 그린다.
    /// 위치를 끄거나 거절했으면 남긴 위치·예보를 지운다(위젯은 계산형 말로).
    static func appBecameActive() async {
        sendWidgetPicks()
        sendWidgetAdded()
        bakeSkies()
        guard let store = AmbientStore() else { return }
        let finder = PlaceFinder.shared
        guard finder.isEnabled, finder.access != .denied else {
            if store.place() != nil || store.forecast() != nil {
                store.clear()
                reloadWidgets()
            }
            return
        }
        if finder.access == .granted, let place = await finder.current() { share(place) }
        let before = store.forecast()
        _ = await AmbientNow.refresh(store: store, source: WeatherKitForecast())
        if store.forecast() != before { reloadWidgets() }
    }

    /// 앱이 위치를 얻을 때마다 — 소수 2자리로 깎아 App Group 에만 둔다.
    static func share(_ place: Place, at date: Date = Date()) {
        try? AmbientStore()?.save(place: SharedPlace(latitude: place.latitude, longitude: place.longitude, at: date))
    }

    static func reloadWidgets() {
        bakeSkies()
        reloadTimelines()
    }

    private static func reloadTimelines() {
        for kind in WordWidgetTimeline.kinds { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
    }

    private static var baking = false

    /// 위젯 물빛 배경 하늘 — 판이 바뀌었거나, 없거나, 밤 하늘의 달이 지난날 것일 때만 굽는다(메인 밖에서).
    static func bakeSkies() {
        guard !baking else { return }
        baking = true
        let scale = UIScreen.main.scale
        Task.detached(priority: .utility) {
            let baked = WordWidgetSky.bakeIfNeeded(scale: scale)
            await MainActor.run {
                baking = false
                if baked { reloadTimelines() }
            }
        }
    }

    // MARK: 계측 — 위젯 확장에는 PostHog 가 없다

    static let sentPicksKey = "telemetrySentWidgetPicks"
    static let widgetAddedKey = "telemetryWidgetAdded"

    /// 위젯에서 주운 줄 중 아직 안 보낸 것 — 보낸 id 는 기억해 두고 다시 보내지 않는다.
    static func unsent(_ lines: [PickLine], sent: Set<String>) -> [PickLine] {
        lines.filter { $0.kind == .pick && $0.source == .widget && !sent.contains($0.id.uuidString) }
    }

    static func sendWidgetPicks(lines: [PickLine]? = PickedWords(writer: .app)?.lines(), defaults: UserDefaults = .standard,
                                send: (Telemetry.Event) -> Void = Telemetry.send) {
        guard let lines else { return }
        var sent = Set(defaults.stringArray(forKey: sentPicksKey) ?? [])
        let fresh = unsent(lines, sent: sent)
        guard !fresh.isEmpty else { return }
        for line in fresh {
            sent.insert(line.id.uuidString)
            if let pick = Telemetry.WordPick(line) { send(.wordPicked(pick)) }
        }
        defaults.set(Array(sent), forKey: sentPicksKey)
    }

    /// 한 번만 — 위젯이 남긴 첫 타임라인 시각, 또는 위젯 붙이기 장에서 붙은 걸 알아챈 순간.
    static func sendWidgetAdded(firstTimelineAt: Date? = WordWidgetAdded.firstTimelineAt(), attachedNow: Bool = false,
                                now: Date = Date(), defaults: UserDefaults = .standard,
                                send: (Telemetry.Event) -> Void = Telemetry.send) {
        guard !defaults.bool(forKey: widgetAddedKey), let at = firstTimelineAt ?? (attachedNow ? now : nil) else { return }
        defaults.set(true, forKey: widgetAddedKey)
        send(.widgetAdded(Telemetry.lag(dayKey: Moment.dayKey(for: at), now: now)))
    }
}
