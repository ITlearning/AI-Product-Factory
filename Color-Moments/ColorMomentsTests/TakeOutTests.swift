import XCTest
@testable import ColorMoments

/// 사진 보기의 「몽돌에서 빼기」 — 저장소 쪽 동작.
@MainActor
final class TakeOutTests: XCTestCase {

    private var tempFile: URL!
    private var closures: DayClosures!
    private var store: DayStore!
    private var suite: String!
    private var defaults: UserDefaults!
    private var savedStamps: PebbleNameLog!

    private let day = "2026-09-22"

    override func setUp() async throws {
        try await super.setUp()
        tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("days-\(UUID().uuidString).json")
        closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        store = DayStore(fileURL: tempFile, closures: closures)
        store.onLocalChange = { _ in }
        suite = "take-out-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        savedStamps = PebbleNaming.stamps
        PebbleNaming.stamps = PebbleNameLog(defaults: defaults)
    }

    override func tearDown() async throws {
        PebbleNaming.stamps = savedStamps
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: tempFile)
        try await super.tearDown()
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: c)!
    }

    /// 사진 앱에 있는 사진 — 자리 이름이라 이 기기에 파일이 없다.
    private func inPhotos(_ at: Date, _ hex: String, asset: String) -> Moment {
        Moment(capturedAt: at, colorHex: hex, fileName: Moment.assetFileName(for: asset), source: .app, assetID: asset)
    }

    func testTakingOutAPhotoRedrawsTheReceivedPebbleButKeepsItsName() {
        let red = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/red")
        let blue = inPhotos(date(2026, 9, 22, 18), "#2233CC", asset: "L/blue")
        store.add(red)
        store.add(blue)
        PebbleNaming.stamp(day, moments: store.pebbleMoments(on: day))
        let stamped = PebbleNaming.name(for: store.pebbleMoments(on: day))
        XCTAssertNotNil(stamped)

        store.takeOut(red.id)

        XCTAssertEqual(store.pebbleMoments(on: day).map(\.id), [blue.id], "조약돌은 남은 사진으로 다시 그린다")
        XCTAssertEqual(PebbleNaming.name(for: store.pebbleMoments(on: day)), stamped, "이름은 도장이라 안 바뀐다")
        XCTAssertTrue(store.finishedDayKeys.contains(day))
    }

    func testTakingOutTheLastPhotoTakesTheDayAway() {
        let only = inPhotos(date(2026, 9, 22, 12), "#CC3322", asset: "L/1")
        store.add(only)
        PebbleNaming.stamp(day, moments: [only])

        store.takeOut(only.id)

        XCTAssertFalse(store.dayKeys.contains(day))
        XCTAssertFalse(store.finishedDayKeys.contains(day), "모은 조약돌에서도 빠진다")
        XCTAssertNil(PebbleNaming.name(for: store.pebbleMoments(on: day)), "도장이 있어도 사진이 없으면 조약돌·이름이 없다")
        XCTAssertTrue(DayStore(fileURL: tempFile, closures: closures).moments.isEmpty, "디스크에서도 빠진다")
    }

    func testTakeOutSendsADeleteThatAnotherDeviceApplies() {
        let a = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/1")
        let b = inPhotos(date(2026, 9, 22, 18), "#2233CC", asset: "L/2")
        store.add(a)
        store.add(b)
        var sent: [StoreChange] = []
        store.onLocalChange = { sent += $0 }

        store.takeOut(a.id)
        XCTAssertEqual(sent, [.delete(a.id)], "CloudSync 가 이 알림으로 deleteRecord 를 올린다")

        let otherFile = FileManager.default.temporaryDirectory.appendingPathComponent("days-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: otherFile) }
        let other = DayStore(fileURL: otherFile, closures: DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        other.applyRemote(upserts: [a, b], deletes: [])
        let deletes = Set(sent.compactMap { change -> Moment.ID? in
            if case .delete(let id) = change { id } else { nil }
        })
        other.applyRemote(upserts: [], deletes: deletes)
        XCTAssertEqual(other.moments.map(\.id), [b.id])
    }

    func testTakingOutAnOpenTodayPhotoWorksToo() {
        let now = inPhotos(Date(), "#CC3322", asset: "L/now")
        store.add(now)
        XCTAssertTrue(store.canClose(Moment.dayKey(for: Date())))

        store.takeOut(now.id)

        XCTAssertTrue(store.today.isEmpty)
        XCTAssertFalse(store.canClose(Moment.dayKey(for: Date())), "빈 오늘은 마무리할 게 없다")
    }

    func testTakeOutDeletesThisDevicesOnlyCopyAfterTheRecordIsSaved() async throws {
        let name = "take-out-\(UUID().uuidString).jpg"
        let url = ShotImage.url(name)
        try Data([1, 2, 3]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let m = Moment(capturedAt: date(2026, 9, 22, 9), colorHex: "#CC3322", fileName: name, source: .app)
        store.add(m)
        XCTAssertEqual(store.fileBacked.map(\.id), [m.id], "사진 앱에 없는 사진 — 확인창이 다시 못 본다고 알리는 경우")

        let cleanup = try XCTUnwrap(store.takeOut(m.id))
        await cleanup.value

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(DayStore(fileURL: tempFile, closures: closures).moments.isEmpty)
    }

    func testTakeOutOfAPhotoInThePhotosAppHasNoFileToDelete() {
        let m = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/1")
        store.add(m)
        XCTAssertNil(store.takeOut(m.id))
        XCTAssertTrue(store.moments.isEmpty)
    }

    func testTakeOutOfAGoneRecordDoesNothing() {
        var sent: [StoreChange] = []
        store.onLocalChange = { sent += $0 }
        XCTAssertNil(store.takeOut(UUID()))
        XCTAssertTrue(sent.isEmpty)
    }

    // 정리가 조회를 기다리는 사이 사용자가 같은 기록을 뺐다 — 정리는 지금 저장소 기준으로 다시 거른다.
    func testReconcilerWaitingOnALookupSkipsARecordTakenOutMeanwhile() {
        let m = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/1")
        store.add(m)
        let snapshot = store.moments
        store.takeOut(m.id)
        XCTAssertTrue(AssetReconciler.removalIDs(snapshot: snapshot, remove: ["L/1"], current: store.moments).isEmpty)
    }

    // MARK: 뺀 사진 기억

    func testRemovedPhotosRemembersTheAssetAndTheLockedSessionName() {
        let locked = Moment(capturedAt: date(2026, 9, 22, 9), colorHex: "#CC3322",
                            fileName: Moment.assetFileName(for: "L/1"), source: .locked,
                            assetID: "L/1", originalName: "shot-1790646372.jpg")
        let fromApp = inPhotos(date(2026, 9, 22, 10), "#2233CC", asset: "L/2")
        RemovedPhotos.note(locked, defaults: defaults)
        RemovedPhotos.note(fromApp, defaults: defaults)
        RemovedPhotos.note(fromApp, defaults: defaults)
        XCTAssertEqual(RemovedPhotos.assetIDs(defaults), ["L/1", "L/2"])
        XCTAssertEqual(RemovedPhotos.originalNames(defaults), ["shot-1790646372.jpg"])
        XCTAssertEqual(defaults.stringArray(forKey: RemovedPhotos.assetKey)?.count, 2, "같은 사진은 한 번만")
    }

    func testRemovedPhotosKeepsOnlyTheNewest() {
        for i in 0...RemovedPhotos.keep {
            RemovedPhotos.note(inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/\(i)"), defaults: defaults)
        }
        let ids = RemovedPhotos.assetIDs(defaults)
        XCTAssertEqual(ids.count, RemovedPhotos.keep)
        XCTAssertFalse(ids.contains("L/0"))
        XCTAssertTrue(ids.contains("L/\(RemovedPhotos.keep)"))
    }

    // 다른 기기에서 뺀 사진 — 이 기기의 ♥ 담기가 다시 담지 않게 받은 쪽도 적는다(CloudSync.apply 와 같은 순서).
    func testAPhotoTakenOutOnAnotherDeviceIsRememberedHere() {
        let m = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/here")
        store.add(m)
        let leaving = store.moments.filter { $0.id == m.id }

        store.applyRemote(upserts: [], deletes: [m.id])
        RemovedPhotos.noteGone(leaving, stillHeld: store.containsAsset, defaults: defaults)

        XCTAssertEqual(RemovedPhotos.assetIDs(defaults), ["L/here"])
    }

    // 중복을 합치느라 지운 기록 — 같은 사진을 넘겨받은 기록이 남아 있으니 뺀 사진이 아니다.
    func testARemoteDeleteThatHandsThePhotoToATwinIsNotRemembered() {
        let local = Moment(capturedAt: date(2026, 9, 22, 9), colorHex: "#CC3322",
                           fileName: Moment.assetFileName(for: "L/1"), source: .app, assetID: "L/1", cloudID: "C/1")
        let twinID = UUID()
        let twin = Moment(id: twinID, capturedAt: date(2026, 9, 22, 9), colorHex: "#CC3322",
                          fileName: Moment.receivedFileName(cloudID: "C/1", id: twinID), source: .app, cloudID: "C/1")
        store.add(local)
        store.add(twin)
        let leaving = store.moments.filter { $0.id == local.id }

        store.applyRemote(upserts: [], deletes: [local.id])
        RemovedPhotos.noteGone(leaving, stillHeld: store.containsAsset, defaults: defaults)

        XCTAssertEqual(store.moments.map(\.assetID), ["L/1"])
        XCTAssertTrue(RemovedPhotos.assetIDs(defaults).isEmpty)
    }

    // MARK: 뺀 다음 보일 사진

    func testAfterTakingOutTheViewMovesToTheNextPhotoOrTheOneBeforeAtTheEnd() {
        let a = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/a")
        let b = inPhotos(date(2026, 9, 22, 12), "#22CC33", asset: "L/b")
        let c = inPhotos(date(2026, 9, 22, 18), "#2233CC", asset: "L/c")
        store.add(c)
        store.add(a)
        store.add(b)
        let day = store.moments(on: self.day)
        XCTAssertEqual(day.map(\.id), [a.id, b.id, c.id], "시간 순 — 하루 상세의 위에서 아래")

        XCTAssertEqual(DayMomentsView.shownAfterTakingOut(a.id, from: day), b.id)
        XCTAssertEqual(DayMomentsView.shownAfterTakingOut(b.id, from: day), c.id)
        XCTAssertEqual(DayMomentsView.shownAfterTakingOut(c.id, from: day), b.id)
    }

    func testTakingOutTheOnlyPhotoClosesTheView() {
        let only = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/only")
        XCTAssertNil(DayMomentsView.shownAfterTakingOut(only.id, from: [only]))
        XCTAssertNil(DayMomentsView.shownAfterTakingOut(UUID(), from: [only]), "그사이 사라졌으면 닫는다")
    }
}
