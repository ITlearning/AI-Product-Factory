import XCTest
@testable import ColorMoments

final class PickedWordsTests: XCTestCase {

    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("picks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func entry(_ id: String, _ word: String, _ meaning: String) throws -> WordEntry {
        let json = #"{"id":"\#(id)","word":"\#(word)","meaning":"\#(meaning)","times":[],"weathers":[],"seasons":[],"subjects":[]}"#
        return try JSONDecoder().decode(WordEntry.self, from: Data(json.utf8))
    }

    private func line(_ l: PickLine) throws -> String {
        String(decoding: try JSONEncoder().encode(l), as: UTF8.self)
    }

    private func write(_ lines: [String], to url: URL) throws {
        try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: url)
    }

    private let t0 = Date(timeIntervalSince1970: 1_760_500_000)

    // MARK: 합치기

    func testMergesBothFilesInterleaved() throws {
        let dir = try tempDir()
        let app = PickedWords(writer: .app, directory: dir)
        let widget = PickedWords(writer: .widget, directory: dir)
        _ = try widget.pick("윤슬", wordID: "w1", source: .widget, at: t0)
        _ = try app.pick("는개", wordID: "w2", source: .photo, photoID: "p1", at: t0.addingTimeInterval(10))
        _ = try widget.pick("는개", wordID: "w2", source: .widget, at: t0.addingTimeInterval(20))
        _ = try app.pick("윤슬", wordID: "w1", source: .photo, photoID: "p2", at: t0.addingTimeInterval(30))

        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("picks-app.jsonl").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("picks-widget.jsonl").path))

        let merged = app.merged(words: [])
        XCTAssertEqual(merged.map(\.word), ["윤슬", "는개"], "가장 최근에 주운 말부터")
        XCTAssertEqual(merged.map(\.count), [2, 2])
        XCTAssertEqual(merged[0].picks.map(\.source), [.widget, .photo], "한 말 안은 시각 순")
        XCTAssertEqual(widget.merged(words: []), merged, "위젯이 읽어도 같은 결과")
    }

    func testSameIDCountsOnce() throws {
        let dir = try tempDir()
        let p = PickLine(kind: .pick, word: "윤슬", source: .widget, at: t0)
        try write([try line(p)], to: dir.appendingPathComponent("picks-widget.jsonl"))
        try write([try line(p), try line(p)], to: dir.appendingPathComponent("picks-app.jsonl"))
        let store = PickedWords(writer: .app, directory: dir)
        XCTAssertEqual(store.lines().count, 1)
        XCTAssertEqual(store.merged(words: []).first?.count, 1)
    }

    func testUnpickBeforePickInFileOrderStillRemoves() throws {
        let dir = try tempDir()
        let p = PickLine(kind: .pick, word: "윤슬", source: .widget, at: t0)
        let keep = PickLine(kind: .pick, word: "윤슬", source: .widget, at: t0.addingTimeInterval(100))
        let u = PickLine(kind: .unpick, word: "윤슬", at: t0.addingTimeInterval(50), targets: [p.id])
        // 앱 파일이 위젯 파일보다 나중에 읽히고, 위젯 파일 안에서도 unpick 이 먼저 온다.
        try write([try line(u)], to: dir.appendingPathComponent("picks-widget.jsonl"))
        try write([try line(keep), try line(p)], to: dir.appendingPathComponent("picks-app.jsonl"))
        let merged = PickedWords(writer: .app, directory: dir).merged(words: [])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].picks.map(\.id), [keep.id], "unpick 은 자기가 가리킨 기록만 지운다")

        let swapped = try tempDir()
        try write([try line(p), try line(keep)], to: swapped.appendingPathComponent("picks-widget.jsonl"))
        try write([try line(u)], to: swapped.appendingPathComponent("picks-app.jsonl"))
        XCTAssertEqual(PickedWords(writer: .app, directory: swapped).merged(words: []), merged, "순서를 바꿔도 같은 결과")
    }

    func testSkipsBrokenLines() throws {
        let dir = try tempDir()
        let a = PickLine(kind: .pick, word: "윤슬", source: .widget, at: t0)
        let b = PickLine(kind: .pick, word: "는개", source: .widget, at: t0.addingTimeInterval(1))
        try write([try line(a), "{\"id\":\"zz", "", "not json", #"{"id":"\#(UUID())","kind":"future","word":"x","at":0}"#, try line(b)],
                  to: dir.appendingPathComponent("picks-widget.jsonl"))
        XCTAssertEqual(PickedWords(writer: .app, directory: dir).merged(words: []).map(\.word), ["는개", "윤슬"])
    }

    func testAppendAfterTornLineStartsOnNewLine() throws {
        let dir = try tempDir()
        let url = dir.appendingPathComponent("picks-widget.jsonl")
        let a = PickLine(kind: .pick, word: "윤슬", source: .widget, at: t0)
        try Data((try line(a) + "\n" + #"{"id":"half"#).utf8).write(to: url)
        let store = PickedWords(writer: .widget, directory: dir)
        _ = try store.pick("는개", source: .widget, at: t0.addingTimeInterval(1))
        XCTAssertEqual(store.merged(words: []).map(\.word), ["는개", "윤슬"], "끊긴 줄에 이어 붙으면 새 줄까지 깨진다")
    }

    func testPickThrowsWhenFileCannotBeWritten() throws {
        let dir = try tempDir()
        // 쓸 파일 자리에 폴더가 있으면 열 수 없다 — 이때 기록을 돌려주면 「주웠어요」가 거짓말이 된다.
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("picks-widget.jsonl"), withIntermediateDirectories: true)
        let store = PickedWords(writer: .widget, directory: dir)
        XCTAssertThrowsError(try store.pick("윤슬", source: .widget, at: t0))
        XCTAssertTrue(store.merged(words: []).isEmpty)
    }

    // MARK: 묶기·뜻풀이

    func testGroupsByTrimmedTextAndPrefersWordsMeaning() throws {
        let dir = try tempDir()
        let app = PickedWords(writer: .app, directory: dir)
        let widget = PickedWords(writer: .widget, directory: dir)
        _ = try app.pick("윤슬", meaning: "생일 목록 뜻", source: .birthday, at: t0)
        _ = try widget.pick(" 윤슬 ", wordID: "w1", source: .widget, at: t0.addingTimeInterval(86_400))
        _ = try app.pick("해맞이", meaning: "떠오르는 해를 맞는 일", source: .birthday, at: t0.addingTimeInterval(5))

        let merged = app.merged(words: [try entry("w1", "윤슬", "words 뜻")])
        XCTAssertEqual(merged.map(\.word), ["윤슬", "해맞이"])
        XCTAssertEqual(merged[0].count, 2, "앞뒤 공백을 뺀 글자로 묶는다")
        XCTAssertEqual(merged[0].meaning, "words 뜻", "words.json 뜻풀이가 먼저")
        XCTAssertEqual(merged[0].wordID, "w1")
        XCTAssertTrue(merged[0].isBirthday, "합친 줄에도 생일 표시는 남는다")
        XCTAssertEqual(merged[1].meaning, "떠오르는 해를 맞는 일", "생일 목록에만 있는 말은 생일 뜻풀이")
        XCTAssertNil(merged[1].wordID)
    }

    // MARK: 빼기

    func testUnpickPhotoRemovesOnlyThatRecord() throws {
        let dir = try tempDir()
        let app = PickedWords(writer: .app, directory: dir)
        let widget = PickedWords(writer: .widget, directory: dir)
        _ = try widget.pick("윤슬", source: .widget, at: t0)
        _ = try app.pick("윤슬", source: .photo, photoID: "p1", at: t0.addingTimeInterval(1))
        _ = try app.pick("는개", source: .photo, photoID: "p2", at: t0.addingTimeInterval(2))

        XCTAssertNotNil(try app.unpick(photoID: "p1"))
        XCTAssertNotNil(try app.unpick(photoID: "p2"))
        XCTAssertNil(try app.unpick(photoID: "p2"), "뺄 게 없으면 쓰지 않는다")
        let merged = app.merged(words: [])
        XCTAssertEqual(merged.map(\.word), ["윤슬"], "남은 기록이 없는 말은 사라진다")
        XCTAssertEqual(merged[0].picks.map(\.source), [.widget], "위젯으로 주운 기록은 남는다")
    }

    func testUnpickWordRemovesAllButLaterPickSurvives() throws {
        let dir = try tempDir()
        let app = PickedWords(writer: .app, directory: dir)
        let widget = PickedWords(writer: .widget, directory: dir)
        _ = try widget.pick("윤슬", source: .widget, at: t0)
        _ = try app.pick("윤슬", source: .photo, photoID: "p1", at: t0.addingTimeInterval(1))
        _ = try app.pick("윤슬", meaning: "m", source: .birthday, at: t0.addingTimeInterval(2))
        XCTAssertEqual(try app.unpick(word: "윤슬 ")?.targets?.count, 3)
        XCTAssertTrue(app.merged(words: []).isEmpty)

        _ = try widget.pick("윤슬", source: .widget, at: t0.addingTimeInterval(3))
        XCTAssertEqual(app.merged(words: []).first?.count, 1, "뺀 뒤 다시 주운 건 남는다")
    }

    // MARK: 하루 한 번

    func testPickedTodayUsesFourAMBoundary() throws {
        let dir = try tempDir()
        let store = PickedWords(writer: .widget, directory: dir)
        let cal = Moment.calendar
        let night = cal.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 2))!
        _ = try store.pick("윤슬", source: .widget, at: night)
        XCTAssertTrue(store.pickedToday("윤슬", now: cal.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 22))!),
                      "새벽 2시는 전날")
        XCTAssertFalse(store.pickedToday("윤슬", now: cal.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 5))!))
        XCTAssertFalse(store.pickedToday("는개", now: night))
    }

    // MARK: 생일 말 — 기대값은 Mongdol-Desk/js/birthday-pick.js 를 node 로 돌린 결과

    func testHashAndRngMatchJS() {
        XCTAssertEqual(BirthdayWords.hash(""), 2166136261)
        XCTAssertEqual(BirthdayWords.hash("seed:10"), 3219774619)
        XCTAssertEqual(BirthdayWords.hash("몽돌🙂:any"), 2737377611)
        let cases: [(UInt32, [Double])] = [
            (2166136261, [0.6112444521859288, 0.4935242917854339, 0.7740248835179955]),
            (3219774619, [0.016838864888995886, 0.28389865392819047, 0.3767903773114085]),
            (2737377611, [0.044776471331715584, 0.5916045769117773, 0.6235231552273035]),
        ]
        for (seed, expected) in cases {
            let r = BirthdayWords.rng(seed)
            XCTAssertEqual([r(), r(), r()], expected, "seed \(seed)")
        }
    }

    func testPickMatchesWebJS() throws {
        let words = try XCTUnwrap(BirthdayWords.load(), "번들에 birthday-words.json 이 없다")
        XCTAssertEqual(words.count, 1275)
        let uuid = "3f2a9c1e-7b4d-4e8a-9f61-2c5d8e0b1a47"
        let expected: [(String, Int, Int, String, String, String, Int)] = [
            (uuid, 1, 1, "해맞이", "눈꽃", "큰곰자리", 91),
            (uuid, 5, 5, "어린이날", "흰제비꽃", "비그이", 113),
            (uuid, 5, 8, "보리누름", "모둠꽃밭", "사랑", 113),
            (uuid, 12, 31, "눈벌", "첫얼음", "고요", 78),
            (uuid, 2, 29, "구들목", "눈꽃바람", "여울돌", 78),
            (uuid, 10, 15, "고욤", "대추", "아기", 83),
            (uuid, 7, 31, "노랑원추리", "여름바람", "집괭이", 82),
            (uuid, 3, 1, "바람개비놀이", "꽃달임", "고샅길", 96),
            (uuid, 6, 30, "풋내음", "보리누름", "달무리", 86),
            (uuid, 11, 11, "청둥오리", "볏가리", "나그넷길", 45),
            ("seed", 1, 1, "눈봉우리", "썰매", "잔별", 91),
            ("seed", 5, 5, "먼지잼", "배추흰나비", "판굿", 113),
            ("seed", 5, 8, "민들레", "꽃꿀", "까치걸음", 113),
            ("seed", 12, 31, "아랫목", "썰매", "맞손", 78),
            ("seed", 2, 29, "따지기", "눈놀이", "웃음빛", 78),
            ("seed", 10, 15, "가을", "가을밤", "해무늬", 83),
            ("seed", 7, 31, "꿀참외", "자귀나무", "철벌레", 82),
            ("seed", 3, 1, "풋나물", "잔풀나기", "얼룩송아지", 96),
            ("seed", 6, 30, "구슬붕이", "꿀벌", "돌잡이", 86),
            ("seed", 11, 11, "담쟁이덩굴", "털실", "실안개", 45),
            ("몽돌🙂", 1, 1, "누비이불", "설눈", "꼬마", 91),
            ("몽돌🙂", 5, 5, "풀피리", "봄잠", "큰곰자리", 113),
            ("몽돌🙂", 5, 8, "어버이날", "딸기", "새벽까치", 113),
            ("몽돌🙂", 12, 31, "해넘이", "곶감", "인절미", 78),
            ("몽돌🙂", 2, 29, "포슬눈", "동박새", "달넘이", 78),
            ("몽돌🙂", 10, 15, "단감", "밤나무", "꽃담", 83),
            ("몽돌🙂", 7, 31, "수무지개", "발등물", "썰물", 82),
            ("몽돌🙂", 3, 1, "버들가지", "진달래꽃", "수수팥떡", 96),
            ("몽돌🙂", 6, 30, "달팽이", "목비", "귀염", 86),
            ("몽돌🙂", 11, 11, "대추차", "무서리", "고양이", 45),
        ]
        for (seed, m, d, w, x1, x2, pool) in expected {
            let got = try XCTUnwrap(BirthdayWords.pick(words, seed: seed, month: m, day: d))
            XCTAssertEqual([got.word] + got.extras.map(\.word), [w, x1, x2], "\(seed) \(m)/\(d)")
            XCTAssertEqual(got.pool, pool, "\(seed) \(m)/\(d)")
        }
    }

    func testBirthdayMeaningComesFromList() throws {
        let words = try XCTUnwrap(BirthdayWords.load())
        let got = try XCTUnwrap(BirthdayWords.pick(words, seed: "3f2a9c1e-7b4d-4e8a-9f61-2c5d8e0b1a47", month: 1, day: 1))
        XCTAssertEqual(got.meaning, "떠오르는 해를 맞는 일")
    }

    func testInstallSeedIsStableAndStaysOnDevice() throws {
        let suite = "picked-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let a = BirthdayWords.installSeed(defaults: defaults)
        XCTAssertEqual(BirthdayWords.installSeed(defaults: defaults), a)
        XCTAssertEqual(a, a.lowercased(), "웹 crypto.randomUUID 와 같은 모양")
        XCTAssertNotEqual(BirthdayWords.installSeed(defaults: nil), a)
    }

    /// 웹(Mongdol-Desk)과 같은 목록 — 한쪽만 고치면 이 검사가 막는다.
    func testBundledListMatchesWebCopy() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let web = try Data(contentsOf: repo.appendingPathComponent("Mongdol-Desk/data/birthday-words.json"))
        let app = try Data(contentsOf: repo.appendingPathComponent("Color-Moments/Shared/Word/birthday-words.json"))
        XCTAssertEqual(app, web, "Shared/Word/birthday-words.json 을 Mongdol-Desk/data 것과 똑같이 맞출 것")
    }
}
