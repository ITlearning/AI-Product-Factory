import Foundation

/// 규칙이 거른 후보 안에서 한 단어를 고를 때 넘기는 것. 모델(Apple Intelligence)은 사진을 못 보므로
/// Vision 라벨과 찍은 때·날씨·곳을 글로 준다. 규칙이 시간대·날씨에 어긋나는 단어를 이미 뺐으니 모델은 고르기만 한다.
public struct WordChoice: Sendable, Equatable {
    public struct Candidate: Sendable, Equatable {
        public let id: String
        public let word: String
        public let meaning: String

        public init(id: String, word: String, meaning: String) {
            self.id = id; self.word = word; self.meaning = meaning
        }
    }

    public let candidates: [Candidate]
    public let labels: [String]
    public let date: Date
    public let weather: String?
    public let place: String?
    /// 규칙과 같은 달력(PhotoContext.calendar(for:)) — 다르면 해외 사진의 후보와 프롬프트 속 시각이 어긋난다.
    public let calendar: Calendar

    public init(candidates: [Candidate], labels: [String], date: Date, weather: String? = nil, place: String? = nil,
                calendar: Calendar = PhotoContext.korea) {
        self.candidates = candidates
        self.labels = labels
        self.date = date
        self.weather = weather
        self.place = place
        self.calendar = calendar
    }

    public static let instructions = """
    사진 일기 앱에서 사진 한 장에 붙일 순우리말 한 단어를 후보 가운데 하나 고른다.
    사진에 보이는 것(Vision 라벨, 잘 보이는 순)과 뜻이 맞는 단어를 가장 먼저 고른다.
    그런 단어가 여럿이면 찍은 때·날씨·곳의 분위기에 가장 잘 맞는 것을 고른다.
    사진에 보이지 않는 것을 말하는 단어는 고르지 않는다. 후보에 없는 말은 쓰지 않는다.
    먼저 후보마다 사진에 보이는 것·날씨·때와 맞는지 따져 까닭에 쓰고, 그다음 단어를 고른다.
    날씨와 어긋나는 후보(맑은 날의 비 말, 눈 오는 날의 진눈깨비 등)나 사진에 없는 것을 말하는 후보는 버린다.
    """

    /// 순서만 뒤집은 같은 물음 — 모델은 앞 후보를 고르는 버릇이 있어 두 번 물어 같을 때만 따른다.
    public var reversed: WordChoice {
        WordChoice(candidates: candidates.reversed(), labels: labels, date: date, weather: weather, place: place, calendar: calendar)
    }

    public func prompt() -> String { prompt(calendar: calendar) }

    public func prompt(calendar: Calendar) -> String {
        let day = DateFormatter()
        day.locale = Locale(identifier: "ko_KR")
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        day.dateFormat = "yyyy년 M월 d일"
        let clock = DateFormatter()
        clock.calendar = calendar
        clock.timeZone = calendar.timeZone
        clock.dateFormat = "HH:mm"
        let season = ["spring": "봄", "summer": "여름", "autumn": "가을", "winter": "겨울"][
            PhotoContext(date: date, calendar: calendar).season.rawValue] ?? ""

        var lines = ["사진에 보이는 것: " + (labels.isEmpty ? "알아보지 못함" : labels.prefix(10).joined(separator: ", "))]
        lines.append("찍은 때: \(day.string(from: date)) \(PhotoEnrichment.partOfDay(date, calendar: calendar))(\(clock.string(from: date))), \(season)")
        if let weather { lines.append("날씨: \(weather)") }
        if let place { lines.append("곳: \(place)") }
        lines.append("후보:")
        lines += candidates.map { "- \($0.word): \($0.meaning)" }
        return lines.joined(separator: "\n")
    }

    /// 모델이 돌려준 말을 후보 id 로 — 후보에 없는 말이면 nil(규칙 1순위로 간다).
    public func candidateID(for answer: String) -> String? {
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        return candidates.first { $0.word == a }?.id
    }
}

public enum WordAssist {
    /// 앱 타깃이 꽂는다 — Apple Intelligence 가 되는 기기만 답한다. 비었거나 nil 이면 규칙 1순위.
    public nonisolated(unsafe) static var choose: (@Sendable (WordChoice) async -> String?)?

    /// 모델이 늦으면 기다리지 않는다 — 단어는 사진을 열 때 붙으니 오래 비워 둘 수 없다.
    public static func choose(_ input: WordChoice, within seconds: Double = 6) async -> String? {
        guard input.candidates.count > 1, let choose else { return nil }
        return await withTaskGroup(of: String?.self) { group in
            group.addTask { await choose(input) }
            group.addTask { try? await Task.sleep(for: .seconds(seconds)); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
