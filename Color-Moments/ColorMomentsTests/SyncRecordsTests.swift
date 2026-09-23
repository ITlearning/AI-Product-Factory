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
