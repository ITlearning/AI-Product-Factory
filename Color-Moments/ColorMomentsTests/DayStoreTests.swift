import XCTest
@testable import ColorMoments

final class DayStoreTests: XCTestCase {

    private var tempFile: URL!
    private var store: DayStore!
    private var closures: DayClosures!

    override func setUp() {
        super.setUp()
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("days-\(UUID().uuidString).json")
        closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        store = DayStore(fileURL: tempFile, closures: closures)
        // 구독 전 변경은 쌓였다가 구독 순간 넘어온다 — 각 테스트는 그 뒤 변경만 보려고 먼저 구독해 둔다.
        store.onLocalChange = { _ in }
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
        let reopened = DayStore(fileURL: tempFile, closures: closures)
        XCTAssertEqual(reopened.moments.count, 1)
        XCTAssertEqual(reopened.moments.first?.colorHex, "#AABBCC")
    }

    func testReadsRecordsSavedWhileColorPickingExisted() throws {
        let legacy = """
        [{"id":"\(UUID().uuidString)","capturedAt":"2026-09-22T03:00:00Z","colorHex":"#F0A896",
          "fileName":"old.jpg","source":"app","colorWasChosen":true}]
        """
        try Data(legacy.utf8).write(to: tempFile)
        let reopened = DayStore(fileURL: tempFile, closures: closures)
        XCTAssertEqual(reopened.moments.first?.colorHex, "#F0A896", "색 고르기 시절 기록이 사라지면 그날 조약돌이 없어진다")
    }

    func testRemoveAllEmptiesTheStore() {
        store.add(moment(date(2026, 9, 22, 12, 0), name: "x.jpg"))
        store.removeAll()
        XCTAssertTrue(store.moments.isEmpty)
        XCTAssertTrue(DayStore(fileURL: tempFile, closures: closures).moments.isEmpty, "파일에서도 지워져야 한다")
    }

    func testAssignWordPersistsAndNeverOverwrites() {
        let m = moment(date(2026, 9, 22, 12, 0), name: "w.jpg")
        store.add(m)
        store.setLabels(m.id, ["rain"])
        store.assignWord(m.id, PhotoWord(wordID: "neungae", word: "는개", meaning: "가는 비"))
        store.assignWord(m.id, PhotoWord(wordID: "yunseul", word: "윤슬", meaning: "잔물결"))
        XCTAssertEqual(DayStore(fileURL: tempFile, closures: closures).moments.first?.word?.wordID, "neungae",
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
        let m = try XCTUnwrap(DayStore(fileURL: tempFile, closures: closures).moments.first)
        XCTAssertNil(m.word)
        XCTAssertEqual(m.colorHex, "#AABBCC")
    }

    func testLabelsPersistAndNeverOverwrite() {
        let m = moment(date(2026, 9, 22, 12, 0), name: "l.jpg")
        store.add(m)
        store.setLabels(m.id, ["sky"])
        store.setLabels(m.id, ["laptop"])
        XCTAssertEqual(DayStore(fileURL: tempFile, closures: closures).moments.first?.labels, ["sky"])
    }

    func testWordWithoutLabelsIsDroppedOnLoad() throws {
        let legacy = """
        [{"id":"\(UUID().uuidString)","capturedAt":"2026-09-22T03:00:00Z","colorHex":"#AABBCC","fileName":"a.jpg","source":"app",
          "word":{"wordID":"haegeoreum","word":"해거름","meaning":"m"}},
         {"id":"\(UUID().uuidString)","capturedAt":"2026-09-22T04:00:00Z","colorHex":"#AABBCC","fileName":"b.jpg","source":"app",
          "labels":["sky"],"word":{"wordID":"meondong","word":"먼동","meaning":"m"}}]
        """
        try Data(legacy.utf8).write(to: tempFile)
        let ms = DayStore(fileURL: tempFile, closures: closures).moments.sorted { $0.fileName < $1.fileName }
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
        let m = try XCTUnwrap(DayStore(fileURL: tempFile, closures: closures).moments.first)
        XCTAssertNil(m.assetID); XCTAssertNil(m.place); XCTAssertNil(m.addedAt); XCTAssertNil(m.batchID)
    }

    func testHasSealedMomentsIsTrueForCameraPhoto() {
        store.add(moment(date(2026, 9, 22, 12, 0), name: "cam.jpg"))
        XCTAssertTrue(store.hasSealedMoments(on: "2026-09-22"), "카메라 사진이 있으면 그 하루는 증정 대상이다")
    }

    func testHasSealedMomentsIsFalseWhenOnlyAddedAfterTheDayEnded() {
        store.add(imported(date(2026, 9, 22, 15, 0), added: date(2026, 9, 25, 10, 0), batch: UUID(), name: "late.jpg"))
        XCTAssertFalse(store.hasSealedMoments(on: "2026-09-22"), "봉인 뒤에만 담긴 사진뿐이면 증정할 조약돌이 없다")
    }

    func testHasSealedMomentsIsTrueWhenAddedBeforeSeal() {
        store.add(imported(date(2026, 9, 22, 15, 0), added: date(2026, 9, 22, 20, 0), batch: UUID(), name: "sameday.jpg"))
        XCTAssertTrue(store.hasSealedMoments(on: "2026-09-22"))
    }

    func testHasSealedMomentsIsFalseForDayWithNoMoments() {
        XCTAssertFalse(store.hasSealedMoments(on: "2026-09-22"))
    }

    func testAdoptPreservesFieldsAndSecondCallIsIgnored() {
        let m = moment(date(2026, 9, 22, 12, 0), "#AABBCC", name: "cam.jpg")
        store.add(m)
        store.setLabels(m.id, ["sky"])
        store.assignWord(m.id, PhotoWord(wordID: "yunseul", word: "윤슬", meaning: "잔물결"))

        XCTAssertTrue(store.adopt(m.id, assetID: "ASSET-1"), "처음 입양은 true 를 돌려줘야 한다")
        let adopted = try! XCTUnwrap(store.moments.first { $0.id == m.id })
        XCTAssertEqual(adopted.assetID, "ASSET-1")
        XCTAssertEqual(adopted.fileName, Moment.assetFileName(for: "ASSET-1"), "자리 이름이 규칙대로 지어져야 한다")
        XCTAssertEqual(adopted.colorHex, "#AABBCC")
        XCTAssertEqual(adopted.labels, ["sky"])
        XCTAssertEqual(adopted.word?.wordID, "yunseul")
        XCTAssertEqual(adopted.capturedAt, m.capturedAt)

        XCTAssertFalse(store.adopt(m.id, assetID: "ASSET-2"),
                       "이미 입양된 Moment 의 두 번째 입양은 false 를 돌려줘야 한다 — 호출부가 파일을 지우면 안 된다는 신호")
        XCTAssertEqual(store.moments.first { $0.id == m.id }?.assetID, "ASSET-1",
                       "이미 입양된 Moment 는 두 번째 입양을 무시해야 한다")
    }

    func testAddReturnsTrueWhenInsertedFalseWhenDuplicate() {
        let first = moment(date(2026, 9, 22, 12, 0), name: "dup.jpg")
        XCTAssertTrue(store.add(first), "처음 넣을 때는 true")
        let duplicate = moment(date(2026, 9, 22, 13, 0), name: "dup.jpg")
        XCTAssertFalse(store.add(duplicate), "같은 fileName 은 false — 넣지 않았다는 신호")
        XCTAssertEqual(store.moments.count, 1)
    }

    func testAddDedupesByOriginalNameEvenAfterFileNameChangedByAdoption() {
        // 잠금화면 세션이 재전달되는 상황을 흉내낸다: 원본 이름은 같은데(originalName),
        // 첫 Moment 는 이미 입양돼 fileName 이 자리 이름으로 바뀌어 있다.
        let original = Moment(capturedAt: date(2026, 9, 22, 12, 0), colorHex: "#112233",
                              fileName: "shot-100.jpg", source: .locked, originalName: "shot-100.jpg")
        store.add(original)
        store.adopt(original.id, assetID: "ASSET-1")
        XCTAssertEqual(store.moments.first?.fileName, Moment.assetFileName(for: "ASSET-1"),
                       "입양 뒤 fileName 은 바뀌어야 정상이다(전제 확인)")

        let redelivered = Moment(capturedAt: date(2026, 9, 22, 12, 1), colorHex: "#445566",
                                 fileName: "shot-100.jpg", source: .locked, originalName: "shot-100.jpg")
        XCTAssertFalse(store.add(redelivered),
                       "fileName 만 비교하면 놓친다 — originalName 이 같으면 재전달된 같은 사진으로 봐야 한다")
        XCTAssertEqual(store.moments.count, 1)
    }

    func testAdoptPreservesOriginalName() {
        let m = Moment(capturedAt: date(2026, 9, 22, 12, 0), colorHex: "#112233",
                       fileName: "shot-1.jpg", source: .locked, originalName: "shot-1.jpg")
        store.add(m)
        store.adopt(m.id, assetID: "ASSET-1")
        XCTAssertEqual(store.moments.first?.originalName, "shot-1.jpg",
                       "입양이 fileName 을 자리 이름으로 바꿔도 originalName 은 남아야 재전달 중복을 잡는다")
    }

    func testReadsRecordsWithoutOriginalName() throws {
        let legacy = """
        [{"id":"\(UUID().uuidString)","capturedAt":"2026-09-22T03:00:00Z","colorHex":"#AABBCC","fileName":"old.jpg","source":"app"}]
        """
        try Data(legacy.utf8).write(to: tempFile)
        let m = try XCTUnwrap(DayStore(fileURL: tempFile, closures: closures).moments.first)
        XCTAssertNil(m.originalName, "옛 기록엔 originalName 이 없다 — nil 로 읽혀야 한다")
    }

    func testRemoveAssetIDsDropsTheDayFromDayKeysWhenEmptied() {
        let m = imported(date(2026, 9, 22, 15, 0), added: date(2026, 9, 22, 20, 0), batch: UUID(),
                         name: Moment.assetFileName(for: "ASSET-1"), asset: "ASSET-1")
        store.add(m)
        XCTAssertTrue(store.dayKeys.contains("2026-09-22"))

        store.remove(assetIDs: ["ASSET-1"])
        XCTAssertTrue(store.moments.isEmpty)
        XCTAssertFalse(store.dayKeys.contains("2026-09-22"), "그 하루의 사진이 다 지워지면 dayKeys 에서도 빠져야 한다")
    }

    func testFileBackedExcludesAdoptedMoments() {
        let file = moment(date(2026, 9, 22, 9, 0), name: "file.jpg")
        let asset = imported(date(2026, 9, 22, 10, 0), added: date(2026, 9, 22, 10, 0), batch: UUID(),
                             name: Moment.assetFileName(for: "ASSET-9"), asset: "ASSET-9")
        store.add(file)
        store.add(asset)
        XCTAssertEqual(store.fileBacked.map(\.fileName), ["file.jpg"])
    }

    func testLocalWritesNotifyChanges() {
        var got: [StoreChange] = []
        store.onLocalChange = { got += $0 }
        let a = moment(date(2026, 9, 20, 12))
        store.add(a)
        store.setLabels(a.id, ["sky"])
        store.remove(assetIDs: [])  // 아무것도 안 지우면 알림 없음
        XCTAssertEqual(got, [.upsert(a.id), .upsert(a.id)])
    }

    func testChangesBeforeSubscriberAreDeliveredOnSubscribe() {
        let fresh = DayStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("days-\(UUID().uuidString).json"), closures: closures)
        let a = Moment(capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-1",
                       source: .library, assetID: "L/1")
        fresh.add(a)
        fresh.setCloudIDs([(a.id, "C1")])
        fresh.remove(assetIDs: ["L/1"])
        var calls: [[StoreChange]] = []
        fresh.onLocalChange = { calls.append($0) }
        XCTAssertEqual(calls, [[.upsert(a.id), .upsert(a.id), .delete(a.id)]],
                       "동기화가 켜지기 전 변경을 버리면 다음 실행부터는 영영 안 올라간다")
        fresh.onLocalChange = { calls.append($0) }
        XCTAssertEqual(calls.count, 1, "쌓인 것은 한 번만 넘긴다")
        let b = moment(date(2026, 9, 20, 13))
        fresh.add(b)
        XCTAssertEqual(calls.last, [.upsert(b.id)])
    }

    func testReassignAssetsSwapsAssetWithoutNotifying() {
        let a = Moment(capturedAt: date(2026, 9, 20, 12), colorHex: "#111111",
                       fileName: Moment.assetFileName(for: "L/1"), source: .library, assetID: "L/1", cloudID: "C1")
        let b = Moment(capturedAt: date(2026, 9, 20, 13), colorHex: "#111111", fileName: "b.jpg", source: .app)
        store.add(a)
        store.add(b)
        var got: [StoreChange] = []
        store.onLocalChange = { got += $0 }
        store.reassignAssets([(a.id, "L/9"), (b.id, "L/8")])
        XCTAssertEqual(store.moment(a.id)?.assetID, "L/9")
        XCTAssertEqual(store.moment(a.id)?.fileName, Moment.assetFileName(for: "L/9"))
        XCTAssertNil(store.moment(b.id)?.assetID, "assetID 가 없던 기록은 바꿔 끼울 대상이 아니다(resolveAssets 몫)")
        XCTAssertTrue(got.isEmpty, "assetID 는 이 기기 전용 — 올릴 것 없음")
        XCTAssertEqual(DayStore(fileURL: tempFile, closures: closures).moment(a.id)?.assetID, "L/9")
    }

    func testRemoveByAssetNotifiesDelete() {
        var got: [StoreChange] = []
        let a = Moment(capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-1",
                       source: .library, assetID: "L/1")
        store.add(a)
        store.onLocalChange = { got += $0 }
        store.remove(assetIDs: ["L/1"])
        XCTAssertEqual(got, [.delete(a.id)])
    }

    func testApplyRemoteDoesNotNotify() {
        var got: [StoreChange] = []
        store.onLocalChange = { got += $0 }
        let r = Moment(capturedAt: date(2026, 9, 20, 12), colorHex: "#111111",
                       fileName: "remote-x", source: .app, cloudID: "C1")
        store.applyRemote(upserts: [r], deletes: [])
        store.applyRemote(upserts: [], deletes: [r.id])
        XCTAssertTrue(got.isEmpty)
        XCTAssertTrue(store.moments.isEmpty)
    }

    func testApplyRemoteKeepsLocalAssetAndReturnsPushWhenLocalKnowsMore() {
        let a = Moment(capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-1",
                       source: .app, word: PhotoWord(wordID: "w", word: "윤슬", meaning: "m"),
                       labels: ["water"], assetID: "L/1")
        store.add(a)
        let server = Moment(id: a.id, capturedAt: a.capturedAt, colorHex: a.colorHex,
                            fileName: "remote-x", source: .app, cloudID: "C1")
        let push = store.applyRemote(upserts: [server], deletes: [])
        let now = store.moment(a.id)!
        XCTAssertEqual(now.assetID, "L/1")
        XCTAssertEqual(now.cloudID, "C1")
        XCTAssertEqual(now.word?.word, "윤슬")
        XCTAssertEqual(push, [.upsert(a.id)], "서버에 없는 단어를 이 기기가 알고 있으면 다시 올린다")
    }

    private let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let yunseul = PhotoWord(wordID: "w", word: "윤슬", meaning: "m")

    func testSameCloudIDRemoteWinsByIDAndInheritsLocalAsset() {
        let local = Moment(id: id2, capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-1",
                           source: .library, assetID: "L/1", cloudID: "C1")
        store.add(local)
        let remote = Moment(id: id1, capturedAt: date(2026, 9, 20, 12, 1), colorHex: "#111111", fileName: "asset-c",
                            source: .library, cloudID: "C1")
        let push = store.applyRemote(upserts: [remote], deletes: [])
        XCTAssertEqual(store.moments.map(\.id), [id1])
        XCTAssertEqual(store.moments.first?.assetID, "L/1", "이긴 기록도 이 기기 에셋 연결은 이어받는다")
        XCTAssertEqual(push, [.delete(id2)])
    }

    func testSameCloudIDRemoteLosesButItsWordIsKept() {
        let local = Moment(id: id1, capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-1",
                           source: .library, assetID: "L/1", cloudID: "C1")
        store.add(local)
        let remote = Moment(id: id2, capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-c",
                            source: .library, word: yunseul, labels: ["water"], cloudID: "C1")
        let push = store.applyRemote(upserts: [remote], deletes: [])
        XCTAssertEqual(store.moments.map(\.id), [id1])
        XCTAssertEqual(store.moments.first?.word, yunseul, "진 쪽의 단어를 버리면 두 기기가 다른 단어를 보게 된다")
        XCTAssertEqual(store.moments.first?.assetID, "L/1")
        XCTAssertEqual(push, [.delete(id2), .upsert(id1)])
    }

    func testSetCloudIDMergesDuplicateIntoReceivedWinner() {
        let received = Moment(id: id1, capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-c",
                              source: .library, cloudID: "C1")
        store.applyRemote(upserts: [received], deletes: [])
        let mine = Moment(id: id2, capturedAt: date(2026, 9, 20, 12, 1), colorHex: "#111111", fileName: "asset-1",
                          source: .library, word: yunseul, labels: ["water"], assetID: "L/1")
        store.add(mine)
        var got: [StoreChange] = []
        store.onLocalChange = { got += $0 }
        store.setCloudID(mine.id, "C1")
        XCTAssertEqual(store.moments.map(\.id), [id1])
        XCTAssertEqual(store.moments.first?.assetID, "L/1")
        XCTAssertEqual(store.moments.first?.word, yunseul, "assetID 가진 쪽이 져도 단어는 남는다")
        XCTAssertEqual(got, [.delete(id2), .upsert(id1)])
    }

    func testSetCloudIDMergesDuplicateIntoMineWhenMineWins() {
        let received = Moment(id: id2, capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-c",
                              source: .library, word: yunseul, labels: ["water"], cloudID: "C1")
        store.applyRemote(upserts: [received], deletes: [])
        let mine = Moment(id: id1, capturedAt: date(2026, 9, 20, 12, 1), colorHex: "#111111", fileName: "asset-1",
                          source: .library, assetID: "L/1")
        store.add(mine)
        var got: [StoreChange] = []
        store.onLocalChange = { got += $0 }
        store.setCloudID(mine.id, "C1")
        XCTAssertEqual(store.moments.map(\.id), [id1])
        XCTAssertEqual(store.moments.first?.assetID, "L/1")
        XCTAssertEqual(store.moments.first?.word, yunseul)
        XCTAssertEqual(got, [.delete(id2), .upsert(id1)])
    }

    func testSetCloudIDsSavesAndNotifiesOnce() {
        let ms = (0..<3).map { k in
            Moment(capturedAt: date(2026, 9, 20, 12, k), colorHex: "#111111", fileName: "asset-\(k)",
                   source: .library, assetID: "L/\(k)")
        }
        ms.forEach { store.add($0) }
        var calls: [[StoreChange]] = []
        store.onLocalChange = { calls.append($0) }
        store.setCloudIDs(ms.enumerated().map { ($1.id, "C\($0)") })
        XCTAssertEqual(calls, [ms.map { .upsert($0.id) }])
        XCTAssertEqual(DayStore(fileURL: tempFile, closures: closures).moments.map(\.cloudID), ["C0", "C1", "C2"])
    }

    /// 두 기기가 같은 사진을 따로 담은 뒤 서로의 기록을 받고, 각자 돌려준 push 를 상대에게 준다.
    private func assertTwoDevicesConverge(aID: UUID, bID: UUID, file: StaticString = #filePath, line: UInt = #line) {
        let t = date(2026, 9, 20, 12)
        let storeA = store!
        let storeB = DayStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("days-\(UUID().uuidString).json"),
                              closures: DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        let a = Moment(id: aID, capturedAt: t, colorHex: "#111111", fileName: "asset-a", source: .library,
                       assetID: "A/1", cloudID: "C1")
        let b = Moment(id: bID, capturedAt: t.addingTimeInterval(0.4), colorHex: "#111111", fileName: "asset-b",
                       source: .library, word: yunseul, labels: ["water"], assetID: "B/1", cloudID: "C1")
        storeA.add(a); storeB.add(b)
        var toB = storeA.applyRemote(upserts: [b], deletes: [])
        var toA = storeB.applyRemote(upserts: [a], deletes: [])
        func deliver(_ push: [StoreChange], from src: DayStore, to dst: DayStore) -> [StoreChange] {
            var ups: [Moment] = [], dels = Set<Moment.ID>()
            for c in push {
                switch c {
                case .upsert(let id): if let m = src.moment(id) { ups.append(m) }
                case .delete(let id): dels.insert(id)
                }
            }
            return dst.applyRemote(upserts: ups, deletes: dels)
        }
        for _ in 0..<5 where !(toA.isEmpty && toB.isEmpty) {
            let nextA = deliver(toB, from: storeA, to: storeB)
            let nextB = deliver(toA, from: storeB, to: storeA)
            (toA, toB) = (nextA, nextB)
        }
        XCTAssertTrue(toA.isEmpty && toB.isEmpty, "push 가 끝나지 않는다", file: file, line: line)
        XCTAssertEqual(storeA.moments.map(\.id), storeB.moments.map(\.id), file: file, line: line)
        XCTAssertEqual(storeA.moments.count, 1, file: file, line: line)
        XCTAssertEqual(storeA.moments.first?.word, yunseul, file: file, line: line)
        XCTAssertEqual(storeB.moments.first?.word, yunseul, file: file, line: line)
        XCTAssertEqual(storeA.moments.first?.assetID, "A/1", file: file, line: line)
        XCTAssertEqual(storeB.moments.first?.assetID, "B/1", file: file, line: line)
        XCTAssertTrue(MomentMerge.syncedEqual(storeA.moments[0], storeB.moments[0]), file: file, line: line)
    }

    func testTwoDevicesConvergeWhenAssetSideWins() { assertTwoDevicesConverge(aID: id1, bID: id2) }

    func testTwoDevicesConvergeWhenWordSideWins() { assertTwoDevicesConverge(aID: id2, bID: id1) }

    func testDeleteAndUpsertOfSameCloudIDInOneBatchKeepsLocalAsset() {
        let a = Moment(id: id2, capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-a",
                       source: .library, assetID: "A/1", cloudID: "C1")
        store.add(a)
        let b = Moment(id: id1, capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-c",
                       source: .library, word: yunseul, labels: ["water"], cloudID: "C1")
        store.applyRemote(upserts: [b], deletes: [a.id])
        XCTAssertEqual(store.moments.map(\.id), [id1])
        XCTAssertEqual(store.moments.first?.assetID, "A/1", "먼저 지우면 이 기기 사진 연결이 사라진다")
        XCTAssertEqual(store.moments.first?.fileName, "asset-a")
        XCTAssertEqual(store.moments.first?.word, yunseul)
    }

    func testDeletedLocalAssetHandsOverToSurvivorWithSameCloudID() throws {
        let a = Moment(id: id2, capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-a",
                       source: .library, assetID: "A/1", originalName: "o.jpg", cloudID: "C1")
        let b = Moment(id: id1, capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "asset-c",
                       source: .library, cloudID: "C1")
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try enc.encode([a, b]).write(to: tempFile)
        let reopened = DayStore(fileURL: tempFile, closures: closures)
        reopened.applyRemote(upserts: [], deletes: [a.id])
        XCTAssertEqual(reopened.moments.map(\.id), [id1])
        XCTAssertEqual(reopened.moments.first?.assetID, "A/1")
        XCTAssertEqual(reopened.moments.first?.fileName, "asset-a")
        XCTAssertEqual(reopened.moments.first?.originalName, "o.jpg")
    }

    func testReceivedMomentDropsOtherDeviceFileFields() {
        let r = Moment(capturedAt: date(2026, 9, 20, 12), colorHex: "#111111", fileName: "shot-other.jpg",
                       source: .app, assetID: "OTHER/1", originalName: "lock.jpg", cloudID: "C1")
        store.applyRemote(upserts: [r], deletes: [])
        let got = store.moment(r.id)
        XCTAssertEqual(got?.fileName, Moment.receivedFileName(cloudID: "C1", id: r.id))
        XCTAssertNil(got?.assetID)
        XCTAssertNil(got?.originalName)
        XCTAssertTrue(store.fileBacked.isEmpty, "다른 기기 파일 이름이면 없는 파일을 입양하려 한다")
    }

    func testRemoveAllDoesNotNotify() {
        store.add(moment(date(2026, 9, 22, 12, 0), name: "x.jpg"))
        var got: [StoreChange] = []
        store.onLocalChange = { got += $0 }
        store.removeAll()
        XCTAssertTrue(got.isEmpty, "디버그 초기화가 다른 기기 기록까지 지우면 안 된다")
    }

    func testCapturedAtKeepsFractionalSecondsAcrossReload() {
        let at = date(2026, 9, 22, 12).addingTimeInterval(0.25)
        let m = moment(at, name: "frac.jpg")
        store.add(m)
        let reloaded = DayStore(fileURL: tempFile, closures: closures).moment(m.id)!
        XCTAssertEqual(reloaded.capturedAt.timeIntervalSince1970, at.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertTrue(MomentMerge.syncedEqual(reloaded, m))
    }

    func testReceivedMomentsAreNotFileBackedAndResolveLater() {
        let r = Moment(capturedAt: date(2026, 9, 20, 12), colorHex: "#111111",
                       fileName: Moment.receivedFileName(cloudID: "C1", id: UUID()), source: .app, cloudID: "C1")
        let orphan = Moment(capturedAt: date(2026, 9, 20, 13), colorHex: "#111111",
                            fileName: Moment.receivedFileName(cloudID: nil, id: UUID()), source: .app)
        store.applyRemote(upserts: [r, orphan], deletes: [])
        XCTAssertTrue(store.fileBacked.isEmpty, "받은 기록은 이 기기에 파일이 없다 — 입양 대상 아님")
        XCTAssertEqual(store.unresolved.map(\.id), [r.id])
        var got: [StoreChange] = []
        store.onLocalChange = { got += $0 }
        store.resolveAsset(r.id, assetID: "L/9")
        XCTAssertEqual(store.moment(r.id)?.assetID, "L/9")
        XCTAssertTrue(store.unresolved.isEmpty)
        XCTAssertTrue(got.isEmpty, "assetID 는 이 기기 전용 — 올릴 것 없음")
    }

    func testOldJSONWithoutCloudIDStillLoads() throws {
        let json = """
        [{"id":"\(UUID().uuidString)","capturedAt":"2026-09-20T03:00:00Z","colorHex":"#111111",
          "fileName":"shot-1.jpg","source":"app"}]
        """
        try Data(json.utf8).write(to: tempFile)
        let reloaded = DayStore(fileURL: tempFile, closures: DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        XCTAssertEqual(reloaded.moments.count, 1)
        XCTAssertNil(reloaded.moments.first?.cloudID)
    }
}
