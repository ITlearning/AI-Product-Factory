import XCTest
@testable import ColorMoments

final class WordChoiceTests: XCTestCase {

    private let seoul: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Seoul")!; return c }()

    private func choice() -> WordChoice {
        let date = seoul.date(from: DateComponents(year: 2025, month: 6, day: 3, hour: 11, minute: 47))!
        return WordChoice(candidates: [.init(id: "yunseul", word: "윤슬", meaning: "반짝이는 잔물결"),
                                       .init(id: "hannat", word: "한낮", meaning: "해가 가장 높이 뜬 때")],
                          labels: ["water", "land"], date: date, weather: "맑음 19°", place: "대천5동")
    }

    func testPromptCarriesWhatTheModelCannotSee() {
        let p = choice().prompt(calendar: seoul)
        XCTAssertTrue(p.contains("사진에 보이는 것: water, land"))
        XCTAssertTrue(p.contains("찍은 때: 2025년 6월 3일 낮(11:47), 여름"), p)
        XCTAssertTrue(p.contains("날씨: 맑음 19°"))
        XCTAssertTrue(p.contains("곳: 대천5동"))
        XCTAssertTrue(p.contains("- 윤슬: 반짝이는 잔물결"))
    }

    func testUnseenPhotoSaysSo() {
        let c = WordChoice(candidates: [], labels: [], date: Date())
        XCTAssertTrue(c.prompt().contains("사진에 보이는 것: 알아보지 못함"))
        XCTAssertFalse(c.prompt().contains("곳:"))
    }

    func testOnlyCandidatesCountAsAnswers() {
        XCTAssertEqual(choice().candidateID(for: " 윤슬\n"), "yunseul")
        XCTAssertNil(choice().candidateID(for: "바다"), "후보 밖 말은 버린다 — 명조 서브셋에 글자도 없다")
    }

    func testReversedAsksTheSameThingInTheOtherOrder() {
        let c = choice()
        XCTAssertEqual(c.reversed.candidates.map(\.id), ["hannat", "yunseul"])
        XCTAssertEqual(c.reversed.labels, c.labels)
        XCTAssertEqual(c.reversed.place, c.place)
    }

    func testNoModelMeansNoAnswer() async {
        let saved = WordAssist.choose
        defer { WordAssist.choose = saved }
        WordAssist.choose = nil
        let answer = await WordAssist.choose(choice())
        XCTAssertNil(answer, "iPhone 13 처럼 모델이 없으면 규칙 1순위")
        WordAssist.choose = { _ in try? await Task.sleep(for: .seconds(5)); return "yunseul" }
        let late = await WordAssist.choose(choice(), within: 0.2)
        XCTAssertNil(late, "늦으면 기다리지 않는다")
    }
}

final class WordRejectionsTests: XCTestCase {

    private var url: URL!

    override func setUp() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("rejections-\(UUID().uuidString).json")
    }

    override func tearDown() { try? FileManager.default.removeItem(at: url) }

    private func entry(_ moment: UUID, _ word: String) -> WordRejections.Entry {
        .init(momentID: moment, wordID: word, replacedBy: "next", labels: ["land"], candidates: [word, "next"],
              partOfDay: "낮", weather: "clear", appVersion: "0.1(1)", at: Date())
    }

    func testOncePerPhotoAndKeptOnThisDevice() {
        let photo = UUID()
        let log = WordRejections(fileURL: url)
        XCTAssertFalse(log.hasRejected(photo))
        log.record(entry(photo, "haze"))
        log.record(entry(photo, "again"))
        let reread = WordRejections(fileURL: url)
        XCTAssertTrue(reread.hasRejected(photo))
        XCTAssertEqual(reread.entries.map(\.wordID), ["haze"], "사진마다 한 번")
    }

    func testWordsRejectedTwiceAreAvoided() {
        let log = WordRejections(fileURL: url)
        log.record(entry(UUID(), "haze"))
        XCTAssertTrue(log.avoided.isEmpty, "한 번은 사진 탓일 수 있다")
        log.record(entry(UUID(), "haze"))
        XCTAssertEqual(log.avoided, ["haze"])
    }

    /// 해외 사진은 규칙과 같은 달력으로 — 파리 한낮 사진의 프롬프트에 「밤(21:00)」이 들어가면 모델이 낮 후보를 버린다.
    func testPromptUsesTheCalendarItWasGiven() {
        var paris = Calendar(identifier: .gregorian); paris.timeZone = TimeZone(secondsFromGMT: 0)!
        var c = DateComponents(); c.year = 2026; c.month = 7; c.day = 15; c.hour = 12; c.timeZone = TimeZone(identifier: "UTC")
        let choice = WordChoice(candidates: [.init(id: "a", word: "가", meaning: "뜻")], labels: [],
                                date: Calendar(identifier: .gregorian).date(from: c)!, calendar: paris)
        XCTAssertTrue(choice.prompt().contains("(12:00)"), choice.prompt())
        XCTAssertTrue(choice.reversed.prompt().contains("(12:00)"), "순서를 뒤집어 물을 때도 같은 달력")
    }
}
