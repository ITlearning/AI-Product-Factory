import SwiftUI
import XCTest
@testable import ColorMoments

final class WordsViewTests: XCTestCase {

    private let words = BundledWordSource.cached
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 21))!

    private func at(_ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: m, day: d, hour: h))!
    }

    private func pick(_ word: String, _ at: Date, _ source: PickLine.Source = .widget, photo: String? = nil) -> PickLine {
        PickLine(kind: .pick, word: word, wordID: words.first { $0.word == word }?.id, source: source, at: at, photoID: photo)
    }

    private func shelf(_ picks: [PickLine], tint: @escaping (String) -> String? = { _ in nil }) -> WordShelf {
        WordShelf.make(PickedWords.merge(PickedWords.live(picks), words: words), entries: words, tint: tint, now: now)
    }

    // MARK: 오늘의 한 장 + 철마다 묶음

    func testEmptyHasNoHeroNoSeasonsNoCount() {
        let s = shelf([])
        XCTAssertTrue(s.isEmpty)
        XCTAssertNil(s.hero)
        XCTAssertTrue(s.seasons.isEmpty)
    }

    func testHeroIsLatestAndNotRepeatedBelow() {
        let s = shelf([pick("는개", at(10, 3)), pick("해거름", at(10, 15, 18)), pick("는개", at(10, 9))])
        XCTAssertEqual(s.count, 2, "서로 다른 말의 수")
        XCTAssertEqual(s.hero?.word, "해거름")
        XCTAssertEqual(s.seasons.flatMap(\.cards).map(\.word), ["는개"])
        XCTAssertEqual(s.seasons.first?.title, "가을 · 10월")
    }

    func testSeasonsFollowPickMonthAndSkipEmpty() {
        let s = shelf([pick("는개", at(7, 20)), pick("새벽녘", at(9, 1, 5)), pick("해거름", at(10, 15, 18)),
                       pick("작달비", at(10, 2))])
        XCTAssertEqual(s.seasons.map(\.title), ["가을 · 10월", "가을 · 9월", "여름 · 7월"])
        XCTAssertTrue(s.seasons.allSatisfy { !$0.cards.isEmpty }, "빈 철은 머리도 없다")
    }

    func testOtherYearShowsYear() {
        let last = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 24, hour: 12))!
        let s = shelf([pick("는개", last), pick("해거름", at(10, 15, 18))])
        XCTAssertEqual(s.seasons.first?.title, "겨울 · 2025년 12월")
    }

    func testMarksCountAndBirthday() {
        let s = shelf([pick("는개", at(10, 1)), pick("는개", at(10, 2)), pick("는개", at(10, 3)),
                       PickLine(kind: .pick, word: "해거름", meaning: "생일 뜻", source: .birthday, at: at(10, 4)),
                       pick("해거름", at(10, 5)),
                       PickLine(kind: .pick, word: "윤나래", meaning: "생일에만 있는 말", source: .birthday, at: at(10, 6)),
                       pick("작달비", at(9, 1))])
        let cards = [s.hero].compactMap { $0 } + s.seasons.flatMap(\.cards)
        let mark = Dictionary(uniqueKeysWithValues: cards.map { ($0.word, $0.mark) })
        XCTAssertEqual(mark["는개"], "세 번")
        XCTAssertEqual(mark["해거름"], "생일 · 두 번")
        XCTAssertEqual(mark["윤나래"], "생일")
        XCTAssertEqual(mark["작달비"], .some(nil), "한 번이면 아무것도")
        XCTAssertEqual(cards.first { $0.word == "윤나래" }?.meaning, "생일에만 있는 말")
    }

    func testCountWords() {
        XCTAssertEqual(WordShelf.countText(2), "두 번")
        XCTAssertEqual(WordShelf.countText(10), "열 번")
        XCTAssertEqual(WordShelf.countText(11), "11번")
    }

    func testOnlyPhotoPicksTintTheSky() {
        let s = shelf([pick("는개", at(10, 2), .photo, photo: "p1"), pick("해거름", at(10, 15, 18))],
                      tint: { $0 == "p1" ? "#AA3355" : nil })
        XCTAssertNil(s.hero?.tintHex)
        XCTAssertEqual(s.seasons.first?.cards.first?.tintHex, "#AA3355")
    }

    func testWhenUsesFourAMBoundary() {
        XCTAssertEqual(WordShelf.when(at(10, 15, 18), now: now), "오늘 저녁")
        XCTAssertEqual(WordShelf.when(at(10, 15, 2), now: now), "어제 밤", "새벽 2시는 전날 밤의 끝")
        XCTAssertEqual(WordShelf.when(at(10, 2, 8), now: now), "10월 2일 아침")
    }

    func testCardReadsAsOneSentence() throws {
        let card = try XCTUnwrap(shelf([pick("는개", at(10, 15, 18)), pick("는개", at(10, 14, 9))]).hero)
        XCTAssertEqual(card.accessibilityText, "는개. 가는 비 장면. 오늘 저녁에 주웠어요. 두 번. 안개보다 굵고 이슬비보다 가는 비")
    }

    // MARK: 사진과 함께 주운 말

    private func tempPicks() throws -> PickedWords {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("picks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return PickedWords(writer: .app, directory: url)
    }

    private func photoWord(_ id: String) throws -> PhotoWord { PhotoWord(try XCTUnwrap(words.first { $0.id == id }, id)) }

    func testPhotoWithTimeWordIsPicked() throws {
        let picks = try tempPicks()
        let line = try XCTUnwrap(try picks.photoWordChanged(photoID: "p1", to: try photoWord("neungae"), at: at(10, 3), words: words))
        XCTAssertEqual(line.source, .photo)
        XCTAssertEqual(line.photoID, "p1")
        XCTAssertEqual(line.wordID, "neungae")
        XCTAssertEqual(picks.merged(words: words).map(\.word), ["는개"])
    }

    func testPhotoWithSubjectWordIsNotPicked() throws {
        let picks = try tempPicks()
        let subject = try XCTUnwrap(words.first { !$0.moment && !$0.ambient && !$0.subjects.isEmpty })
        XCTAssertNil(try picks.photoWordChanged(photoID: "p1", to: PhotoWord(subject), at: at(10, 3), words: words))
        XCTAssertTrue(picks.lines().isEmpty, "대상 말은 1.2 에서 주운 말에 안 들어간다")
    }

    func testSameWordOncePerDayAcrossPhotos() throws {
        let picks = try tempPicks()
        XCTAssertNotNil(try picks.photoWordChanged(photoID: "p1", to: try photoWord("neungae"), at: at(10, 3, 9), words: words))
        XCTAssertNil(try picks.photoWordChanged(photoID: "p2", to: try photoWord("neungae"), at: at(10, 3, 15), words: words))
        XCTAssertNotNil(try picks.photoWordChanged(photoID: "p3", to: try photoWord("neungae"), at: at(10, 4, 9), words: words))
        XCTAssertEqual(picks.merged(words: words).first?.count, 2, "다른 날 다시 주우면 두 번")
    }

    func testRejectedWordLeavesOnlyThatPhotosPick() throws {
        let picks = try tempPicks()
        _ = try picks.pick("는개", wordID: "neungae", source: .widget, at: at(10, 2))
        _ = try picks.photoWordChanged(photoID: "p1", to: try photoWord("neungae"), at: at(10, 3), words: words)
        let subject = try XCTUnwrap(words.first { !$0.moment && !$0.ambient && !$0.subjects.isEmpty })
        XCTAssertNil(try picks.photoWordChanged(photoID: "p1", to: PhotoWord(subject), at: at(10, 3), words: words))
        let merged = picks.merged(words: words)
        XCTAssertEqual(merged.map(\.word), ["는개"], "위젯으로 주운 기록은 남는다")
        XCTAssertEqual(merged.first?.picks.map(\.source), [.widget])
    }

    func testTakingPhotoOutRemovesOnlyItsPick() throws {
        let picks = try tempPicks()
        _ = try picks.photoWordChanged(photoID: "p1", to: try photoWord("neungae"), at: at(10, 3), words: words)
        _ = try picks.unpick(photoID: "p1")
        XCTAssertTrue(picks.merged(words: words).isEmpty)
    }

    // MARK: 화면 덤프 — TEST_RUNNER_WORDS_SHOTS=<폴더> 일 때만

    @MainActor
    func testDumpScreens() throws {
        guard let dir = ProcessInfo.processInfo.environment["WORDS_SHOTS"] else { throw XCTSkip("덤프 폴더 없음") }
        let full = shelf([pick("해거름", at(10, 15, 18)), pick("는개", at(10, 14, 9), .photo, photo: "p1"),
                          pick("는개", at(10, 9)), pick("작달비", at(10, 6)),
                          PickLine(kind: .pick, word: "가을볕", wordID: "gaeulbyeot", source: .birthday, at: at(10, 1)),
                          pick("새벽녘", at(9, 21, 5)), pick("는개", at(7, 3))],
                         tint: { $0 == "p1" ? "#C27A4E" : nil })
        let neungae = try XCTUnwrap(words.first { $0.id == "neungae" })
        func page(_ phase: WordsView.Phase, _ s: WordShelf, now: WordCardModel? = nil, picked: Bool = false) -> some View {
            VStack(spacing: 0) {
                WordsHeader(count: s.count)
                WordsPage(phase: phase, shelf: s, now: now, nowLooked: true, picked: picked, attribution: nil,
                          active: false, visible: [], lazy: false)
            }
            .frame(width: 390)
            .background(Tone.base)
        }
        let shots: [(String, AnyView)] = [
            ("empty", AnyView(page(.ready, .empty, now: WordShelf.now(neungae)))),
            ("empty-picked", AnyView(page(.ready, .empty, now: WordShelf.now(neungae), picked: true))),
            ("list", AnyView(page(.ready, full))),
            ("list-large", AnyView(page(.ready, full).environment(\.dynamicTypeSize, .accessibility2))),
            ("failed", AnyView(page(.failed, .empty))),
            ("opened", AnyView(OpenedWordSheet(model: try XCTUnwrap(full.seasons.first?.cards.first), remove: {}).content
                .frame(width: 390).background(Tone.base))),
        ]
        for (name, view) in shots {
            let r = ImageRenderer(content: view.environment(\.colorScheme, .dark))
            r.scale = 2
            let data = try XCTUnwrap(r.uiImage?.pngData(), name)
            try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
