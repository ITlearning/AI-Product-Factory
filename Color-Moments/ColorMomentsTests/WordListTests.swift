import XCTest
import Vision
@testable import ColorMoments

final class WordListTests: XCTestCase {

    private func list() throws -> WordList { try XCTUnwrap(BundledWordSource.load(), "words.json 을 못 읽었다") }

    func testBundledListDecodes() throws {
        XCTAssertGreaterThanOrEqual(try list().words.count, 30)
    }

    func testIDsAreUniqueAndStable() throws {
        let ids = try list().words.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "id 가 겹친다 — 사진에 붙은 단어가 엉뚱한 단어로 바뀐다")
        XCTAssertTrue(ids.allSatisfy { $0.range(of: "^[a-z]+$", options: .regularExpression) != nil })
    }

    func testEveryWordHasAMeaning() throws {
        for w in try list().words {
            XCTAssertFalse(w.word.isEmpty); XCTAssertFalse(w.meaning.isEmpty, w.word)
        }
    }

    func testPebbleNamesAreCollected() throws {
        var pebble = Set<String>()
        for r in stride(from: 0, through: 255, by: 17) {
            for g in stride(from: 0, through: 255, by: 17) {
                for b in stride(from: 0, through: 255, by: 17) {
                    let m = Moment(capturedAt: Date(), colorHex: String(format: "#%02X%02X%02X", r, g, b),
                                   fileName: "x.jpg", source: .app)
                    if let n = PebbleNaming.name(for: [m]) { pebble.insert(n.name) }
                }
            }
        }
        XCTAssertGreaterThan(pebble.count, 15, "색 구간을 훑었는데 이름이 거의 안 나왔다")
        // 이름은 날짜·제철에 따라 돌아서 색만 훑으면 일부만 나온다.
        pebble.formUnion(PebbleNaming.allNames.map(\.name))
    }

    func testSourceReturnsTheSameWords() async throws {
        let a = await BundledWordSource().words()
        XCTAssertEqual(a, try list().words)
    }

    func testMostWordsHaveSubjects() throws {
        let words = try list().words
        XCTAssertGreaterThan(words.filter { !$0.subjects.isEmpty }.count, 40,
                             "대상이 없는 단어는 쉰다 — 대부분은 대상이 있어야 한다")
    }

    func testEverySubjectIsARealVisionLabel() throws {
        let supported: Set<String>
        do { supported = Set(try VNClassifyImageRequest().supportedIdentifiers()) }
        catch { throw XCTSkip("이 환경에서 Vision 분류 목록을 못 읽는다: \(error)") }
        let bad = try list().words.flatMap { w in (w.subjects + w.with).filter { !supported.contains($0) }.map { "\(w.word):\($0)" } }
        XCTAssertTrue(bad.isEmpty, "Vision 에 없는 분류 이름 — 이 단어는 영영 안 나온다: \(bad)")
    }

    /// WeatherKit 원래 이름 — 틀리면 그 단어는 영영 안 나온다.
    func testConditionsAreRealWeatherKitNames() throws {
        let unknown = try list().words.flatMap { w in w.conditions.filter { PhotoEnrichment.wordWeather($0) == nil }.map { "\(w.word):\($0)" } }
        XCTAssertTrue(unknown.isEmpty, "몽돌이 모르는 날씨 이름: \(unknown)")
    }

    func testRetiredWordsAreNotInTheList() throws {
        let l = try list()
        XCTAssertTrue(Set(l.retired).isDisjoint(with: l.words.map(\.id)))
    }
    private func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json", subdirectory: "Fixtures")))
    }

    func testOldWordsKeepTheirConditions() throws {
        let old = try JSONDecoder().decode(WordList.self, from: fixture("words-v5"))
        let now = Dictionary(uniqueKeysWithValues: try list().words.map { ($0.id, $0) })
        for o in old.words {
            let n = try XCTUnwrap(now[o.id], "\(o.word) 가 사라졌다 — 이미 붙은 사진에서 지워진다")
            XCTAssertEqual([n.times.map(\.rawValue), n.weathers.map(\.rawValue), n.seasons.map(\.rawValue), n.subjects, n.with,
                            n.conditions, n.needs.map(\.rawValue), n.months.map(String.init), n.hours.map(String.init),
                            n.weekdays.map(String.init)],
                           [o.times.map(\.rawValue), o.weathers.map(\.rawValue), o.seasons.map(\.rawValue), o.subjects, o.with,
                            o.conditions, o.needs.map(\.rawValue), o.months.map(String.init), o.hours.map(String.init),
                            o.weekdays.map(String.init)], "\(o.word) 조건이 바뀌었다 — 넓히면 옛 기기가 지운다")
            XCTAssertEqual([n.sunMin, n.sunMax, n.minCelsius, n.maxCelsius], [o.sunMin, o.sunMax, o.minCelsius, o.maxCelsius], o.word)
            XCTAssertEqual(n.moonAges, o.moonAges, o.word)
        }
    }

    func testNewIDsNeverReuseHistory() throws {
        let history = Set(try JSONDecoder().decode([String].self, from: fixture("word-ids-history")))
        let old = Set(try JSONDecoder().decode(WordList.self, from: fixture("words-v5")).words.map(\.id))
        let reused = try list().words.map(\.id).filter { !old.contains($0) && history.contains($0) }
        XCTAssertTrue(reused.isEmpty, "예전 id·retired 를 다시 썼다: \(reused)")
    }

    func testNewMeaningsAreClean() throws {
        let old = Set(try JSONDecoder().decode(WordList.self, from: fixture("words-v5")).words.map(\.id))
        for w in try list().words where !old.contains(w.id) {
            XCTAssertLessThanOrEqual(w.meaning.count, 40, w.word)
            XCTAssertNil(w.meaning.range(of: "[0-9‘’「」]", options: .regularExpression), "\(w.word): \(w.meaning)")
        }
    }

    func testEveryWordHasAGroup() throws {
        XCTAssertTrue(try list().words.allSatisfy { $0.group != nil })
    }

    func testEveryLunarKeyIsInTheTable() throws {
        let inTable = Set(LunarDays.load().values.flatMap { $0 })
        let missing = try list().words.flatMap(\.lunar).filter { !inTable.contains($0) }
        XCTAssertTrue(missing.isEmpty, "음력 표에 없는 날: \(missing)")
    }
}
