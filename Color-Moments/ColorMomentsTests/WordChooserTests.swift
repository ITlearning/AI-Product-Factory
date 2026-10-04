import XCTest
@testable import ColorMoments

final class WordChooserTests: XCTestCase {
    private var attempts: WordAttempts!
    private let ctx = PhotoContext(date: Date(timeIntervalSince1970: 18 * 3600),
                                   calendar: { var c = Calendar(identifier: .gregorian); c.timeZone = .gmt; return c }())
    private let m = Moment(capturedAt: Date(timeIntervalSince1970: 18 * 3600), colorHex: "#888888", fileName: "x.jpg", source: .app)

    private func w(_ id: String, group: String = "물·땅", rest: Bool = false, subjects: [String] = []) -> WordEntry {
        var e = WordEntry(id: id, word: id, meaning: "뜻", times: [], weathers: [], seasons: [], subjects: subjects)
        e.group = group; e.rest = rest; return e
    }

    override func setUp() {
        super.setUp()
        attempts = WordAttempts(defaults: UserDefaults(suiteName: "WordChooserTests")!)
        attempts.clear(m.id)
    }
    override func tearDown() { WordScorer.score = nil; super.tearDown() }

    private func choose(_ words: [WordEntry], recent: Set<String> = [], banned: Set<String> = [], pebble: String? = nil,
                        skip: WordEntry? = nil, labels: [String] = ["ocean"]) async -> WordChooser.Outcome? {
        await WordChooser.choose(moment: m, context: ctx, labels: labels, words: words, recent: recent, banned: banned,
                                 pebbleName: pebble, skip: skip, attempts: attempts)
    }

    private func id(_ o: WordChooser.Outcome?) -> String? { if case .word(let w, _) = o { return w.id }; return nil }

    func testHighestScoreWins() async {
        WordScorer.score = { _ in ["a": 0.2, "b": 0.9] }
        let r1 = id(await choose([w("a"), w("b")])); XCTAssertEqual(r1, "b")
    }

    func testRestedWordIsNeverPicked() async {
        WordScorer.score = { _ in ["a": 0.2, "b": 0.9] }
        let r2 = id(await choose([w("a"), w("b", rest: true)])); XCTAssertEqual(r2, "a")
    }

    func testRecentWordIsAvoidedButNotIfItIsTheOnlyOne() async {
        WordScorer.score = { _ in ["a": 0.2, "b": 0.9] }
        let r3 = id(await choose([w("a"), w("b")], recent: ["b"])); XCTAssertEqual(r3, "a")
        let r4 = id(await choose([w("b")], recent: ["b"])); XCTAssertEqual(r4, "b")
    }

    func testPebbleNameOfTheDayIsSkipped() async {
        WordScorer.score = { _ in ["노을": 0.9, "윤슬": 0.5] }
        let r5 = id(await choose([w("노을"), w("윤슬")], pebble: "노을")); XCTAssertEqual(r5, "윤슬")
    }

    func testRetryRejectsTheSameGroup() async {
        WordScorer.score = { _ in ["a": 0.9, "b": 0.8, "c": 0.1] }
        let words = [w("a"), w("b"), w("c", group: "빛·하늘")]
        let r6 = id(await choose(words, banned: ["a"], skip: words[0])); XCTAssertEqual(r6, "c", "↻ 는 1등과 같은 갈래를 건너뛴다")
    }

    func testNoScorerUsesTheRule() async {
        WordScorer.score = nil
        let r7 = id(await choose([w("sea", subjects: ["ocean"]), w("b")])); XCTAssertEqual(r7, "sea")
    }

    func testFailureLeavesItForLater() async {
        WordScorer.score = { _ in throw WordScorer.Failure.unavailable }
        if case .later = await choose([w("a")]) {} else { XCTFail("실패하면 이번엔 비워 둔다") }
        XCTAssertEqual(attempts.failures(m.id), 1)
    }

    func testThirdFailureFallsBackToRule() async {
        WordScorer.score = { _ in throw WordScorer.Failure.unavailable }
        attempts.fail(m.id); attempts.fail(m.id)
        let r = id(await choose([w("sea", subjects: ["ocean"])]))
        XCTAssertEqual(r, "sea")
        XCTAssertEqual(attempts.failures(m.id), 0, "규칙 단어를 붙이면 기록을 지운다")
    }

    func testFirstAndSecondFailureStayLater() async {
        WordScorer.score = { _ in throw WordScorer.Failure.unavailable }
        attempts.fail(m.id)
        if case .later = await choose([w("sea", subjects: ["ocean"])]) {} else { XCTFail("2번째 실패는 비워 둔다") }
        XCTAssertEqual(attempts.failures(m.id), 2)
    }

    func testRuleFallbackAlsoAvoidsPebbleName() async {
        WordScorer.score = nil
        let r = id(await choose([w("sea", subjects: ["ocean"]), w("b", subjects: ["ocean"])], pebble: "sea"))
        XCTAssertEqual(r, "b")
    }

    func testNonFiniteScoresAreIgnored() {
        let r = WordPicker.best(["a": .nan, "b": 0.1], among: [w("a"), w("b")], seed: "s", notInGroupOf: nil)?.id
        XCTAssertEqual(r, "b")
    }

    func testCancellationIsNotAFailure() async {
        WordScorer.score = { _ in try await Task.sleep(for: .seconds(5)); return [:] }
        let words = [w("a")]
        let t = Task { await self.choose(words) }
        try? await Task.sleep(for: .milliseconds(100))
        t.cancel()
        _ = await t.value
        XCTAssertEqual(attempts.failures(m.id), 0)
    }

    func testScorerThatIgnoresCancellationStillTimesOut() async {
        WordScorer.score = { _ in Thread.sleep(forTimeInterval: 3); return [:] }
        let start = Date()
        _ = try? await WordScorer.scores(for: m, within: 0.2)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    }

    func testSlowScorerTimesOut() async {
        WordScorer.score = { _ in try await Task.sleep(for: .seconds(5)); return [:] }
        let start = Date()
        _ = try? await WordScorer.scores(for: m, within: 0.2)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    }

    func testTiesAreBrokenTheSameWayOnEveryDevice() {
        let words = [w("a"), w("b")]
        let x = WordPicker.best(["a": 0.50001, "b": 0.50002], among: words, seed: "s", notInGroupOf: nil)?.id
        let y = WordPicker.best(["a": 0.50001, "b": 0.50002], among: words.reversed(), seed: "s", notInGroupOf: nil)?.id
        XCTAssertEqual(x, y, "fp16 차이로 기기마다 1등이 갈리지 않게 반올림 후 seed 로")
    }
}
