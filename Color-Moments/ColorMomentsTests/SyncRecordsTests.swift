import CloudKit
import XCTest
@testable import ColorMoments

final class SyncRecordsTests: XCTestCase {

    func testMomentRoundTripDropsDeviceOnlyFields() {
        let m = Moment(capturedAt: Date(timeIntervalSince1970: 1_790_000_000), colorHex: "#A1B2C3",
                       fileName: "asset-abc", source: .locked,
                       word: PhotoWord(wordID: "w1", word: "윤슬", meaning: "잔물결"), labels: ["water", "sky"],
                       assetID: "LOCAL/1", place: Place(latitude: 37.5, longitude: 127, accuracy: 20, name: "한강"),
                       addedAt: Date(timeIntervalSince1970: 1_790_000_100), batchID: UUID(),
                       originalName: "session-1.jpg", cloudID: "CLOUD/1")
        let r = CKRecord(recordType: "Moment", recordID: SyncRecords.recordID(moment: m.id))
        SyncRecords.fill(r, with: m)
        XCTAssertNil(r["assetID"]); XCTAssertNil(r["fileName"]); XCTAssertNil(r["originalName"])
        let back = SyncRecords.moment(from: r)!
        XCTAssertEqual(back.id, m.id)
        XCTAssertTrue(MomentMerge.syncedEqual(back, m))
        XCTAssertNil(back.assetID)
        XCTAssertEqual(back.fileName, Moment.receivedFileName(cloudID: "CLOUD/1", id: m.id))
    }

    func testMomentWithoutOptionalsRoundTrips() {
        let m = Moment(capturedAt: Date(timeIntervalSince1970: 1_790_000_000), colorHex: "#000000",
                       fileName: "shot-1.jpg", source: .app)
        let r = CKRecord(recordType: "Moment", recordID: SyncRecords.recordID(moment: m.id))
        SyncRecords.fill(r, with: m)
        let back = SyncRecords.moment(from: r)!
        XCTAssertTrue(MomentMerge.syncedEqual(back, m))
        XCTAssertTrue(back.fileName.hasPrefix("remote-"))
    }

    private func classified(labels: [String]?, word: PhotoWord?) -> Moment {
        Moment(capturedAt: Date(timeIntervalSince1970: 1_790_000_000), colorHex: "#A1B2C3",
               fileName: "shot-1.jpg", source: .app, word: word, labels: labels)
    }

    private let yunseul = PhotoWord(wordID: "w1", word: "윤슬", meaning: "잔물결")

    func testEmptyLabelsRoundTripKeepsWord() {
        let m = classified(labels: [], word: yunseul)
        let r = CKRecord(recordType: "Moment", recordID: SyncRecords.recordID(moment: m.id))
        SyncRecords.fill(r, with: m)
        let back = SyncRecords.moment(from: r)!
        XCTAssertEqual(back.labels, [])
        XCTAssertEqual(back.word, yunseul)
        XCTAssertTrue(MomentMerge.syncedEqual(back, m), "[] 와 nil 이 갈리면 매번 다시 올린다")
    }

    func testEmptyLabelsSurviveWhenCloudKitDropsTheEmptyArray() {
        let m = classified(labels: [], word: yunseul)
        let r = CKRecord(recordType: "Moment", recordID: SyncRecords.recordID(moment: m.id))
        SyncRecords.fill(r, with: m)
        r["labels"] = nil  // 서버 왕복에서 빈 배열이 빠져 돌아온 경우
        let back = SyncRecords.moment(from: r)!
        XCTAssertEqual(back.labels, [], "labelsEmpty 표식으로 「분류했는데 없음」을 복원한다")
        XCTAssertEqual(back.word, yunseul)
        XCTAssertTrue(MomentMerge.syncedEqual(back, m))
    }

    func testOldRecordWithWordButNoLabelsKeepsWord() {
        let m = classified(labels: [], word: yunseul)
        let r = CKRecord(recordType: "Moment", recordID: SyncRecords.recordID(moment: m.id))
        SyncRecords.fill(r, with: m)
        r["labels"] = nil
        r["labelsEmpty"] = nil  // 표식 전 버전이 올린 기록
        let back = SyncRecords.moment(from: r)!
        XCTAssertEqual(back.labels, [])
        XCTAssertEqual(back.word, yunseul)
    }

    func testUnclassifiedStaysNil() {
        let m = classified(labels: nil, word: nil)
        let r = CKRecord(recordType: "Moment", recordID: SyncRecords.recordID(moment: m.id))
        SyncRecords.fill(r, with: m)
        XCTAssertNil(r["labelsEmpty"])
        XCTAssertNil(SyncRecords.moment(from: r)!.labels, "아직 분류 안 한 것(nil)은 [] 로 바꾸지 않는다")
    }

    func testNonEmptyLabelsClearTheEmptyMark() {
        let r = CKRecord(recordType: "Moment", recordID: SyncRecords.recordID(moment: UUID()))
        SyncRecords.fill(r, with: classified(labels: [], word: yunseul))
        SyncRecords.fill(r, with: classified(labels: ["sky"], word: yunseul))
        XCTAssertNil(r["labelsEmpty"], "같은 레코드를 다시 채울 때 옛 표식이 남으면 안 된다")
    }

    func testDayRoundTripAndRefs() {
        let d = SyncRecords.DayState(dayKey: "2026-09-22", closedAt: Date(timeIntervalSince1970: 1_790_000_000), gifted: true)
        let r = CKRecord(recordType: "Day", recordID: SyncRecords.recordID(day: d.dayKey))
        SyncRecords.fill(r, with: d)
        XCTAssertEqual(SyncRecords.day(from: r), d)
        let id = UUID()
        guard case .moment(let got) = SyncRecords.ref(SyncRecords.recordID(moment: id)) else { return XCTFail() }
        XCTAssertEqual(got, id)
        guard case .day(let key) = SyncRecords.ref(SyncRecords.recordID(day: "2026-09-22")) else { return XCTFail() }
        XCTAssertEqual(key, "2026-09-22")
        XCTAssertNil(SyncRecords.ref(CKRecord.ID(recordName: "x", zoneID: SyncRecords.zoneID)))
    }

    func testMalformedMomentIsSkipped() {
        let r = CKRecord(recordType: "Moment", recordID: SyncRecords.recordID(moment: UUID()))
        XCTAssertNil(SyncRecords.moment(from: r), "필수 필드가 없으면 버린다 — 크래시 금지")
    }
}
