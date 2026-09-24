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

    func testNoWordCollidesWithAPebbleName() throws {
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
        let clash = try list().words.map(\.word).filter(pebble.contains)
        XCTAssertTrue(clash.isEmpty, "조약돌 이름과 겹친다: \(clash)")
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
        let bad = try list().words.flatMap { w in w.subjects.filter { !supported.contains($0) }.map { "\(w.word):\($0)" } }
        XCTAssertTrue(bad.isEmpty, "Vision 에 없는 분류 이름 — 이 단어는 영영 안 나온다: \(bad)")
    }
}
