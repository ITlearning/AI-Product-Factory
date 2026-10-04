import XCTest
@testable import ColorMoments

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
}
