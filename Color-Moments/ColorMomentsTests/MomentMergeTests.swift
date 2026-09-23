import XCTest
@testable import ColorMoments

final class MomentMergeTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    private let word = PhotoWord(wordID: "w1", word: "윤슬", meaning: "햇빛에 반짝이는 잔물결")

    private func m(id: UUID = UUID(), at: Date? = nil, word: PhotoWord? = nil, labels: [String]? = nil,
                   assetID: String? = nil, cloudID: String? = nil, file: String = "f.jpg") -> Moment {
        Moment(id: id, capturedAt: at ?? t0, colorHex: "#112233", fileName: file, source: .app,
               word: word, labels: labels, assetID: assetID, cloudID: cloudID)
    }

    func testServerWordWinsWhenPresent() {
        let id = UUID()
        let local = m(id: id, word: PhotoWord(wordID: "w2", word: "노을", meaning: "x"), labels: ["sky"])
        let remote = m(id: id, word: word, labels: ["water"])
        let merged = MomentMerge.merge(local: local, remote: remote)
        XCTAssertEqual(merged.word, word)
        XCTAssertEqual(merged.labels, ["water"])
    }

    func testLocalWordKeptWhenServerHasNone() {
        let id = UUID()
        let merged = MomentMerge.merge(local: m(id: id, word: word, labels: ["water"]), remote: m(id: id))
        XCTAssertEqual(merged.word, word)
        XCTAssertEqual(merged.labels, ["water"])
    }

    func testDeviceOnlyFieldsStayLocal() {
        let id = UUID()
        let merged = MomentMerge.merge(local: m(id: id, assetID: "LOCAL/1", file: "asset-abc"),
                                       remote: m(id: id, cloudID: "CLOUD", file: "remote-x"))
        XCTAssertEqual(merged.assetID, "LOCAL/1")
        XCTAssertEqual(merged.fileName, "asset-abc")
        XCTAssertEqual(merged.cloudID, "CLOUD")
    }

    func testKeepsIsDeterministic() {
        let a = m(at: t0), b = m(at: t0.addingTimeInterval(1))
        XCTAssertTrue(MomentMerge.keeps(a, over: b))
        XCTAssertFalse(MomentMerge.keeps(b, over: a))
        let x = m(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let y = m(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        XCTAssertTrue(MomentMerge.keeps(x, over: y))
        XCTAssertFalse(MomentMerge.keeps(y, over: x))
    }

    func testSyncedEqualIgnoresDeviceOnlyFields() {
        let id = UUID()
        XCTAssertTrue(MomentMerge.syncedEqual(m(id: id, assetID: "A", file: "a"), m(id: id, assetID: nil, file: "b")))
        XCTAssertFalse(MomentMerge.syncedEqual(m(id: id), m(id: id, word: word, labels: ["x"])))
    }
}
