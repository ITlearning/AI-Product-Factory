import XCTest
@testable import ColorMoments

final class DayStoreTests: XCTestCase {

    private var tempFile: URL!
    private var store: DayStore!

    override func setUp() {
        super.setUp()
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("days-\(UUID().uuidString).json")
        store = DayStore(fileURL: tempFile)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFile)
        super.tearDown()
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: c)!
    }

    private func moment(_ at: Date, _ hex: String = "#112233", name: String? = nil) -> Moment {
        Moment(capturedAt: at, colorHex: hex,
               fileName: name ?? "shot-\(Int(at.timeIntervalSince1970)).jpg", source: .app)
    }

    func testDayBoundaryIsFourInTheMorning() {
        XCTAssertEqual(Moment.dayKey(for: date(2026, 9, 22, 23, 30)), "2026-09-22")
        XCTAssertEqual(Moment.dayKey(for: date(2026, 9, 23, 1, 0)), "2026-09-22",
                       "새벽 1시는 아직 어제여야 한다")
        XCTAssertEqual(Moment.dayKey(for: date(2026, 9, 23, 3, 59)), "2026-09-22",
                       "3시 59분까지 어제")
        XCTAssertEqual(Moment.dayKey(for: date(2026, 9, 23, 4, 0)), "2026-09-23",
                       "4시부터 오늘")
    }

    func testNightShotsGroupIntoOneDay() {
        store.add(moment(date(2026, 9, 22, 22, 0), name: "a.jpg"))
        store.add(moment(date(2026, 9, 23, 0, 30), name: "b.jpg"))
        store.add(moment(date(2026, 9, 23, 2, 0), name: "c.jpg"))
        store.add(moment(date(2026, 9, 23, 9, 0), name: "d.jpg"))

        XCTAssertEqual(store.moments(on: "2026-09-22").count, 3)
        XCTAssertEqual(store.moments(on: "2026-09-23").count, 1)
    }

    func testMomentsAreReturnedInCaptureOrder() {
        store.add(moment(date(2026, 9, 22, 18, 0), name: "late.jpg"))
        store.add(moment(date(2026, 9, 22, 9, 0), name: "early.jpg"))
        XCTAssertEqual(store.moments(on: "2026-09-22").map(\.fileName), ["early.jpg", "late.jpg"])
    }

    func testDuplicateFileNameIsIgnored() {
        store.add(moment(date(2026, 9, 22, 12, 0), name: "same.jpg"))
        store.add(moment(date(2026, 9, 22, 13, 0), name: "same.jpg"))
        XCTAssertEqual(store.moments.count, 1)
    }

    func testPersistsAcrossInstances() {
        store.add(moment(date(2026, 9, 22, 12, 0), "#AABBCC", name: "p.jpg"))
        let reopened = DayStore(fileURL: tempFile)
        XCTAssertEqual(reopened.moments.count, 1)
        XCTAssertEqual(reopened.moments.first?.colorHex, "#AABBCC")
    }

    func testReadsRecordsSavedWhileColorPickingExisted() throws {
        let legacy = """
        [{"id":"\(UUID().uuidString)","capturedAt":"2026-09-22T03:00:00Z","colorHex":"#F0A896",
          "fileName":"old.jpg","source":"app","colorWasChosen":true}]
        """
        try Data(legacy.utf8).write(to: tempFile)
        let reopened = DayStore(fileURL: tempFile)
        XCTAssertEqual(reopened.moments.first?.colorHex, "#F0A896", "색 고르기 시절 기록이 사라지면 그날 조약돌이 없어진다")
    }

    func testRemoveAllEmptiesTheStore() {
        store.add(moment(date(2026, 9, 22, 12, 0), name: "x.jpg"))
        store.removeAll()
        XCTAssertTrue(store.moments.isEmpty)
        XCTAssertTrue(DayStore(fileURL: tempFile).moments.isEmpty, "파일에서도 지워져야 한다")
    }

    func testAssignWordPersistsAndNeverOverwrites() {
        let m = moment(date(2026, 9, 22, 12, 0), name: "w.jpg")
        store.add(m)
        store.setLabels(m.id, ["rain"])
        store.assignWord(m.id, PhotoWord(wordID: "neungae", word: "는개", meaning: "가는 비"))
        store.assignWord(m.id, PhotoWord(wordID: "yunseul", word: "윤슬", meaning: "잔물결"))
        XCTAssertEqual(DayStore(fileURL: tempFile).moments.first?.word?.wordID, "neungae",
                       "한 번 붙은 단어가 바뀌면 같은 사진이 뽑기가 된다")
    }

    func testRecentWordIDsMatchNewestFirstWhenAskingPhotoIsTheLatest() {
        for i in 0..<5 {
            let m = moment(date(2026, 9, 22, 8 + i, 0), name: "r\(i).jpg")
            store.add(m)
            store.assignWord(m.id, PhotoWord(wordID: "w\(i)", word: "w", meaning: "m"))
        }
        let asking = store.moments.first { $0.fileName == "r4.jpg" }!
        XCTAssertEqual(store.recentWordIDs(excluding: asking.id, limit: 2), ["w3", "w2"],
                       "묻는 사진이 가장 최신이면 촬영 시각이 가까운 순 = 최신순과 같다")
    }

    func testRecentWordIDsPrefersSameDayPhotosOverNewerOnes() {
        for i in 0..<20 {
            let m = moment(date(2026, 9, 22, 8, 0).addingTimeInterval(Double(i) * 60), name: "new\(i).jpg")
            store.add(m)
            store.assignWord(m.id, PhotoWord(wordID: "new\(i)", word: "w", meaning: "m"))
        }
        let sibling = moment(date(2026, 8, 1, 12, 5), name: "sibling.jpg")
        store.add(sibling)
        store.assignWord(sibling.id, PhotoWord(wordID: "sibling", word: "w", meaning: "m"))

        let asking = moment(date(2026, 8, 1, 12, 0), name: "asking.jpg")
        store.add(asking)

        let ids = store.recentWordIDs(excluding: asking.id, limit: 14)
        XCTAssertTrue(ids.contains("sibling"),
                      "옛날 하루의 사진에 물으면 최신 20장보다 같은 날 사진의 단어가 먼저 들어가야 한다")
    }

    func testReadsRecordsSavedBeforeWordsExisted() throws {
        let legacy = """
        [{"id":"\(UUID().uuidString)","capturedAt":"2026-09-22T03:00:00Z","colorHex":"#AABBCC",
          "fileName":"pre.jpg","source":"app"}]
        """
        try Data(legacy.utf8).write(to: tempFile)
        let m = try XCTUnwrap(DayStore(fileURL: tempFile).moments.first)
        XCTAssertNil(m.word)
        XCTAssertEqual(m.colorHex, "#AABBCC")
    }

    func testLabelsPersistAndNeverOverwrite() {
        let m = moment(date(2026, 9, 22, 12, 0), name: "l.jpg")
        store.add(m)
        store.setLabels(m.id, ["sky"])
        store.setLabels(m.id, ["laptop"])
        XCTAssertEqual(DayStore(fileURL: tempFile).moments.first?.labels, ["sky"])
    }

    func testWordWithoutLabelsIsDroppedOnLoad() throws {
        let legacy = """
        [{"id":"\(UUID().uuidString)","capturedAt":"2026-09-22T03:00:00Z","colorHex":"#AABBCC","fileName":"a.jpg","source":"app",
          "word":{"wordID":"haegeoreum","word":"해거름","meaning":"m"}},
         {"id":"\(UUID().uuidString)","capturedAt":"2026-09-22T04:00:00Z","colorHex":"#AABBCC","fileName":"b.jpg","source":"app",
          "labels":["sky"],"word":{"wordID":"meondong","word":"먼동","meaning":"m"}}]
        """
        try Data(legacy.utf8).write(to: tempFile)
        let ms = DayStore(fileURL: tempFile).moments.sorted { $0.fileName < $1.fileName }
        XCTAssertNil(ms[0].word, "사진을 안 보고 붙은 옛 단어는 지운다")
        XCTAssertEqual(ms[1].word?.wordID, "meondong", "사진을 보고 붙은 단어는 그대로")
    }

    private func imported(_ at: Date, added: Date, batch: UUID, name: String, asset: String? = nil) -> Moment {
        Moment(capturedAt: at, colorHex: "#445566", fileName: name, source: .library,
               assetID: asset ?? name, addedAt: added, batchID: batch)
    }

    func testSealDateIsNextDayAtFour() throws {
        var c = Calendar(identifier: .gregorian); c.timeZone = .current
        let seal = try XCTUnwrap(Moment.sealDate(for: "2026-09-22"))
        let p = c.dateComponents([.year, .month, .day, .hour], from: seal)
        XCTAssertEqual([p.year, p.month, p.day, p.hour], [2026, 9, 23, 4])
    }

    func testPhotoAddedAfterSealStaysOutOfThePebble() {
        let cam = moment(date(2026, 9, 22, 12, 0), name: "cam.jpg")
        store.add(cam)
        store.add(imported(date(2026, 9, 22, 15, 0), added: date(2026, 9, 25, 10, 0), batch: UUID(), name: "late.jpg"))
        XCTAssertEqual(store.pebbleMoments(on: "2026-09-22").map(\.fileName), ["cam.jpg"],
                       "선물로 받은 조약돌을 나중에 다시 칠하지 않는다")
        XCTAssertEqual(store.moments(on: "2026-09-22").count, 2, "시간축에는 보인다")
    }

    func testPhotoAddedBeforeSealCounts() {
        store.add(imported(date(2026, 9, 22, 15, 0), added: date(2026, 9, 22, 20, 0), batch: UUID(), name: "sameday.jpg"))
        XCTAssertEqual(store.pebbleMoments(on: "2026-09-22").map(\.fileName), ["sameday.jpg"])
    }

    func testEmptyPastDayIsMadeByItsFirstBatchOnly() {
        let first = UUID(), second = UUID()
        store.add(imported(date(2026, 8, 1, 9, 0), added: date(2026, 9, 23, 10, 0), batch: first, name: "a.jpg"))
        store.add(imported(date(2026, 8, 1, 18, 0), added: date(2026, 9, 23, 10, 0), batch: first, name: "b.jpg"))
        store.add(imported(date(2026, 8, 1, 12, 0), added: date(2026, 9, 24, 10, 0), batch: second, name: "c.jpg"))
        XCTAssertEqual(store.pebbleMoments(on: "2026-08-01").map(\.fileName), ["a.jpg", "b.jpg"],
                       "조약돌 없던 날은 처음 담은 묶음이 하루가 되고, 다음 묶음은 빠진다")
    }

    func testContainsAsset() {
        store.add(imported(date(2026, 9, 22, 15, 0), added: date(2026, 9, 22, 20, 0), batch: UUID(), name: "x.jpg", asset: "ASSET-1"))
        XCTAssertTrue(store.containsAsset("ASSET-1"))
        XCTAssertFalse(store.containsAsset("ASSET-2"))
    }

    func testReadsRecordsWithoutLibraryFields() throws {
        let legacy = """
        [{"id":"\(UUID().uuidString)","capturedAt":"2026-09-22T03:00:00Z","colorHex":"#AABBCC","fileName":"old.jpg","source":"app"}]
        """
        try Data(legacy.utf8).write(to: tempFile)
        let m = try XCTUnwrap(DayStore(fileURL: tempFile).moments.first)
        XCTAssertNil(m.assetID); XCTAssertNil(m.place); XCTAssertNil(m.addedAt); XCTAssertNil(m.batchID)
    }
}
