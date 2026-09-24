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

    private let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    func testKeepsIsDecidedByIDOnly() {
        let x = m(id: id1, at: t0.addingTimeInterval(60)), y = m(id: id2, at: t0)
        XCTAssertTrue(MomentMerge.keeps(x, over: y), "capturedAt 정밀도가 기기마다 달라도 같은 답이어야 한다")
        XCTAssertFalse(MomentMerge.keeps(y, over: x))
    }

    func testCombineIsSymmetricAndTakesWordFromLoserWhenWinnerHasNone() {
        let place = Place(latitude: 1, longitude: 2, accuracy: 3)
        var a = m(id: id1, assetID: "L/1", cloudID: "C1", file: "asset-1")
        a.originalName = "orig.jpg"
        var b = m(id: id2, at: t0.addingTimeInterval(-5), word: word, labels: ["water"], cloudID: "C1", file: "asset-c")
        b.place = place
        let ab = MomentMerge.combine(a, b), ba = MomentMerge.combine(b, a)
        XCTAssertEqual(ab, ba)
        XCTAssertEqual(ab.id, id1)
        XCTAssertEqual(ab.capturedAt, t0)
        XCTAssertEqual(ab.word, word)
        XCTAssertEqual(ab.labels, ["water"])
        XCTAssertEqual(ab.place, place)
        XCTAssertEqual(ab.assetID, "L/1")
        XCTAssertEqual(ab.fileName, "asset-1")
        XCTAssertEqual(ab.originalName, "orig.jpg")
    }

    func testCombineKeepsWinnerWordAndLoserAsset() {
        let other = PhotoWord(wordID: "w2", word: "노을", meaning: "x")
        let a = m(id: id1, word: word, labels: ["water"], cloudID: "C1", file: "asset-c")
        let b = m(id: id2, word: other, labels: ["sky"], assetID: "L/2", cloudID: "C1", file: "asset-2")
        let c = MomentMerge.combine(b, a)
        XCTAssertEqual(c.id, id1)
        XCTAssertEqual(c.word, word)
        XCTAssertEqual(c.labels, ["water"])
        XCTAssertEqual(c.assetID, "L/2", "이 기기 사진 연결은 가진 쪽에서 가져온다")
        XCTAssertEqual(c.fileName, "asset-2")
    }

    func testCombineTakesWinnerAssetWhenBothHaveOne() {
        let a = m(id: id1, assetID: "L/1", file: "asset-1"), b = m(id: id2, assetID: "L/2", file: "asset-2")
        XCTAssertEqual(MomentMerge.combine(b, a).assetID, "L/1")
    }

    func testSyncedEqualIgnoresSubMillisecondDifference() {
        let id = UUID()
        let a = Moment(id: id, capturedAt: t0.addingTimeInterval(0.1234567), colorHex: "#112233",
                       fileName: "f", source: .app, addedAt: t0.addingTimeInterval(0.9876543))
        let b = Moment(id: id, capturedAt: t0.addingTimeInterval(0.123), colorHex: "#112233",
                       fileName: "f", source: .app, addedAt: t0.addingTimeInterval(0.987))
        XCTAssertTrue(MomentMerge.syncedEqual(a, b), "CloudKit·days.json 정밀도 차이로 끝없이 다시 올리면 안 된다")
        let c = Moment(id: id, capturedAt: t0.addingTimeInterval(0.2), colorHex: "#112233", fileName: "f", source: .app,
                       addedAt: b.addedAt)
        XCTAssertFalse(MomentMerge.syncedEqual(a, c))
    }

    func testSyncedEqualIgnoresDeviceOnlyFields() {
        let id = UUID()
        XCTAssertTrue(MomentMerge.syncedEqual(m(id: id, assetID: "A", file: "a"), m(id: id, assetID: nil, file: "b")))
        XCTAssertFalse(MomentMerge.syncedEqual(m(id: id), m(id: id, word: word, labels: ["x"])))
    }
}
