import Foundation

/// 「밀려온 말」 위젯 한 칸에 그릴 것 — 홈 작은 위젯·잠금화면 세 자리·온보딩 미리보기가 같이 쓴다.
public struct WordWidgetModel: Equatable, Sendable {
    public enum Pick: Equatable, Sendable {
        case open
        /// 줍기가 디스크에 닿은 직후 1.5초 — 「주웠어요」.
        case justPicked
        /// 그날(새벽 4시 경계) 이미 주운 말 — 버튼 자리에 작은 조약돌만.
        case picked
    }

    public let date: Date
    public let word: String?
    public let wordID: String?
    public let meaning: String?
    public let scene: SceneKind?
    public let moonAge: Double
    public var pick: Pick
    public let sentence: WordWidgetText.Sentence?
    public let short: String?

    public init(date: Date, word: String?, wordID: String?, meaning: String?, scene: SceneKind?, moonAge: Double,
                pick: Pick, sentence: WordWidgetText.Sentence?, short: String?) {
        self.date = date
        self.word = word
        self.wordID = wordID
        self.meaning = meaning
        self.scene = scene
        self.moonAge = moonAge
        self.pick = pick
        self.sentence = sentence
        self.short = short
    }

    /// words.json 을 못 읽었을 때 — 틀린 말보다 빈 게 낫다(빈 장면 + 「몽돌」만).
    public static func blank(_ date: Date) -> WordWidgetModel {
        WordWidgetModel(date: date, word: nil, wordID: nil, meaning: nil, scene: nil, moonAge: 0, pick: .open,
                        sentence: nil, short: nil)
    }

    public func accessibilityText(_ text: WordWidgetText?) -> String? {
        guard let word, let scene else { return text?.brand }
        return [word, text?.sceneLabel(scene), sentence?.plain, meaning].compactMap { $0 }.joined(separator: ". ")
    }
}

/// 방금 위젯에서 주운 말 — 줍기 인텐트가 디스크에 쓴 뒤에만 App Group 에 남긴다.
public struct JustPicked: Codable, Equatable, Sendable {
    public let word: String
    public let at: Date

    public init(word: String, at: Date) {
        self.word = word
        self.at = at
    }

    static let key = "wordWidget.justPicked"

    public static func read(_ defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) -> JustPicked? {
        defaults?.data(forKey: key).flatMap { try? JSONDecoder().decode(JustPicked.self, from: $0) }
    }

    public func write(_ defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) {
        defaults?.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}

public enum WordWidgetTimeline {
    public static let kind = "com.itlearning.colormoments.word-widget"
    public static let lockKind = "com.itlearning.colormoments.word-lock"
    public static let kinds: Set<String> = [kind, lockKind]

    /// 「주웠어요」를 보이는 시간.
    public static let pickedHold: TimeInterval = 1.5
    /// 줍기 뒤 타임라인이 이보다 늦게 불리면 「주웠어요」 없이 바로 조약돌.
    static let justPickedWindow: TimeInterval = 10
    /// 24칸을 한 번에 만들고 3시간 뒤 다시 부른다(예보 재조회와 같은 주기).
    public static let reloadAfter: TimeInterval = ForecastCache.refetchAfter
    /// 위젯을 누르면 「말」 칸.
    public static let url = URL(string: "mongdol://widget/words")!

    /// 순수 함수 — 칸(말 고르기)과 주운 기록으로 위젯 엔트리를 만든다.
    public static func models(slots: [AmbientNow.Slot], picks: [PickLine], justPicked: JustPicked?, now: Date,
                              text: WordWidgetText?) -> [WordWidgetModel] {
        var pickedByDay: [String: Set<String>] = [:]
        for p in picks { pickedByDay[Moment.dayKey(for: p.at), default: []].insert(p.key) }
        var out: [WordWidgetModel] = slots.map { slot in
            guard let w = slot.word, let scene = slot.scene else { return .blank(slot.date) }
            let picked = pickedByDay[Moment.dayKey(for: slot.date)]?.contains(w.word.trimmingCharacters(in: .whitespacesAndNewlines)) ?? false
            return WordWidgetModel(date: slot.date, word: w.word, wordID: w.id, meaning: w.meaning, scene: scene,
                                   moonAge: slot.moonAge, pick: picked ? .picked : .open,
                                   sentence: text?.sentence(w.word, id: w.id, scene: scene),
                                   short: text?.short(w.word, scene: scene))
        }
        if let first = out.first, let just = justPicked, first.word == just.word, first.pick == .picked,
           now.timeIntervalSince(just.at) >= 0, now.timeIntervalSince(just.at) < justPickedWindow {
            out[0].pick = .justPicked
            let settled = WordWidgetModel(date: now.addingTimeInterval(pickedHold), word: first.word, wordID: first.wordID,
                                          meaning: first.meaning, scene: first.scene, moonAge: first.moonAge, pick: .picked,
                                          sentence: first.sentence, short: first.short)
            if out.count < 2 || out[1].date > settled.date { out.insert(settled, at: 1) }
        }
        return out
    }

    /// words.json 을 못 읽으면 빈 장면 한 칸.
    static func models(now: Date, forecast: ForecastCache?, place: SharedPlace?, picks: [PickLine],
                              justPicked: JustPicked?, words: [WordEntry] = BundledWordSource.cached,
                              text: WordWidgetText? = WordWidgetText.cached) -> [WordWidgetModel] {
        guard !words.isEmpty else { return [.blank(now)] }
        let slots = AmbientNow.slots(from: now, forecast: forecast, place: place, in: words)
        return models(slots: slots, picks: picks, justPicked: justPicked, now: now, text: text)
    }
}

/// 새로 붙이는 위젯의 모양 — 앱 설정 「위젯 모양」. 위젯마다 「위젯 편집」에서 따로 바꿀 수 있다.
public enum WordWidgetLook {
    public static let key = "wordWidgetLook"
    public static let store = UserDefaults(suiteName: WidgetSnapshot.appGroup) ?? .standard

    public static var current: SceneStyle {
        store.string(forKey: key).flatMap(SceneStyle.init(rawValue:)) ?? .wash
    }
}

/// 위젯이 붙었다는 표시 — 확장엔 계측이 없어 첫 타임라인 시각만 App Group 에 남기고, 앱이 다음에 열릴 때 한 번 보낸다.
public enum WordWidgetAdded {
    static let key = "wordWidget.firstTimelineAt"

    public static func mark(now: Date = Date(), _ defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) {
        guard let defaults, defaults.object(forKey: key) == nil else { return }
        defaults.set(now, forKey: key)
    }

    public static func firstTimelineAt(_ defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) -> Date? {
        defaults?.object(forKey: key) as? Date
    }
}
