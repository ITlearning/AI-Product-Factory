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

    /// 다른 기기에서 받았는데 이 기기 사진을 아직 못 찾은 기록 — cloudID 만 있다.
    private func unresolved(_ at: Date, cloud: String) -> Moment {
        let id = UUID()
        return Moment(id: id, capturedAt: at, colorHex: "#CC3322",
                      fileName: Moment.receivedFileName(cloudID: cloud, id: id), source: .app, cloudID: cloud)
    }

    /// 사진 권한 없는 다른 기기가 찍은 사진 — 그 기기에만 파일이 있고 여기선 자리 이름뿐이다.
    private func onlyOnAnotherDevice(_ at: Date) -> Moment {
        let id = UUID()
        return Moment(id: id, capturedAt: at, colorHex: "#CC3322",
                      fileName: Moment.receivedFileName(cloudID: nil, id: id), source: .locked)
    }

    private func writeShot() throws -> (name: String, url: URL) {
        let name = "take-out-\(UUID().uuidString).jpg"
        let url = ShotImage.url(name)
        try Data([1, 2, 3]).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return (name, url)
    }

    func testTakingOutAPhotoRedrawsTheReceivedPebbleButKeepsItsName() {
        let red = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/red")
        let blue = inPhotos(date(2026, 9, 22, 18), "#2233CC", asset: "L/blue")
        store.add(red)
        store.add(blue)
        PebbleNaming.stamp(day, moments: store.pebbleMoments(on: day))
        let stamped = PebbleNaming.name(for: store.pebbleMoments(on: day))
        XCTAssertNotNil(stamped)

        store.takeOut(red.id, noting: defaults)

        XCTAssertEqual(store.pebbleMoments(on: day).map(\.id), [blue.id], "조약돌은 남은 사진으로 다시 그린다")
        XCTAssertEqual(PebbleNaming.name(for: store.pebbleMoments(on: day)), stamped, "이름은 도장이라 안 바뀐다")
        XCTAssertTrue(store.finishedDayKeys.contains(day))
    }

    func testTakingOutTheLastPhotoTakesTheDayAway() {
        let only = inPhotos(date(2026, 9, 22, 12), "#CC3322", asset: "L/1")
        store.add(only)
        PebbleNaming.stamp(day, moments: [only])

        store.takeOut(only.id, noting: defaults)

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

        store.takeOut(a.id, noting: defaults)
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

        store.takeOut(now.id, noting: defaults)

        XCTAssertTrue(store.today.isEmpty)
        XCTAssertFalse(store.canClose(Moment.dayKey(for: Date())), "빈 오늘은 마무리할 게 없다")
    }

    func testTakeOutDeletesThisDevicesOnlyCopyAfterTheRecordIsSaved() async throws {
        let shot = try writeShot()
        let m = Moment(capturedAt: date(2026, 9, 22, 9), colorHex: "#CC3322", fileName: shot.name, source: .app)
        store.add(m)

        let cleanup = try XCTUnwrap(store.takeOut(m.id, noting: defaults))
        await cleanup.value

        XCTAssertFalse(FileManager.default.fileExists(atPath: shot.url.path))
        XCTAssertTrue(DayStore(fileURL: tempFile, closures: closures).moments.isEmpty)
    }

    func testTakeOutOfAPhotoInThePhotosAppHasNoFileToDelete() {
        let m = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/1")
        store.add(m)
        XCTAssertNil(store.takeOut(m.id, noting: defaults))
        XCTAssertTrue(store.moments.isEmpty)
    }

    func testTakeOutOfAGoneRecordDoesNothing() {
        var sent: [StoreChange] = []
        store.onLocalChange = { sent += $0 }
        XCTAssertNil(store.takeOut(UUID(), noting: defaults))
        XCTAssertTrue(sent.isEmpty)
        XCTAssertTrue(RemovedPhotos.assetIDs(defaults).isEmpty)
    }

    // 정리가 조회를 기다리는 사이 사용자가 같은 기록을 뺐다 — 정리는 지금 저장소 기준으로 다시 거른다.
    func testReconcilerWaitingOnALookupSkipsARecordTakenOutMeanwhile() {
        let m = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/1")
        store.add(m)
        let snapshot = store.moments
        store.takeOut(m.id, noting: defaults)
        XCTAssertTrue(AssetReconciler.removalIDs(snapshot: snapshot, remove: ["L/1"], current: store.moments).isEmpty)
    }

    // MARK: 확인창 문구

    func testPhotosWithAnAssetOrACloudIDStayInThePhotosApp() {
        let local = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/1")
        let received = unresolved(date(2026, 9, 22, 12), cloud: "C/1")
        let copy = Moment(capturedAt: date(2026, 9, 22, 15), colorHex: "#2233CC",
                          fileName: "library-1.jpg", source: .library, assetID: "L/2")
        for m in [local, received, copy] { store.add(m) }

        for m in [local, received, copy] {
            XCTAssertTrue(DayPhotoView.takeOutNote(m, store: store).hasPrefix("사진 앱에는 그대로 남아요."), m.fileName)
        }
    }

    // 2026-10-03 검토 F1: 다른 기기에만 파일로 있는 사진(remote-)에 「사진 앱에는 그대로」라고 했다 — 빼면 그 기기가 파일을 지운다.
    func testPhotosWithNeitherAnAssetNorACloudIDAreGoneForGood() {
        let elsewhere = onlyOnAnotherDevice(date(2026, 9, 22, 9))
        let here = Moment(capturedAt: date(2026, 9, 22, 12), colorHex: "#2233CC", fileName: "shot-1.jpg", source: .app)
        store.add(elsewhere)
        store.add(here)

        for m in [elsewhere, here] {
            XCTAssertTrue(DayPhotoView.takeOutNote(m, store: store).hasPrefix("사진 앱에 없는 사진이라 빼면 다시 볼 수 없어요."),
                          m.fileName)
        }
    }

    func testTheNoteTalksAboutThePebbleOnlyOnceTheDayIsReceived() {
        let a = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/a")
        let b = inPhotos(date(2026, 9, 22, 18), "#2233CC", asset: "L/b")
        let now = inPhotos(Date(), "#22CC33", asset: "L/now")
        for m in [a, b, now] { store.add(m) }

        XCTAssertEqual(DayPhotoView.takeOutNote(a, store: store), "사진 앱에는 그대로 남아요. 조약돌은 남은 사진으로 다시 그려져요.")
        XCTAssertEqual(DayPhotoView.takeOutNote(now, store: store), "사진 앱에는 그대로 남아요.", "안 닫힌 오늘은 색이 아직 없다")
        store.takeOut(b.id, noting: defaults)
        XCTAssertEqual(DayPhotoView.takeOutNote(a, store: store), "사진 앱에는 그대로 남아요. 이 하루의 조약돌도 사라져요.")
    }

    // MARK: 뺀 사진 기억

    func testTakeOutRemembersTheAssetTheCloudIDAndTheLockedSessionName() {
        let locked = Moment(capturedAt: date(2026, 9, 22, 9), colorHex: "#CC3322",
                            fileName: Moment.assetFileName(for: "L/1"), source: .locked,
                            assetID: "L/1", originalName: "shot-1790646372.jpg", cloudID: "C/1")
        store.add(locked)

        store.takeOut(locked.id, noting: defaults)

        XCTAssertEqual(RemovedPhotos.assetIDs(defaults), ["L/1"])
        XCTAssertEqual(RemovedPhotos.cloudIDs(defaults), ["C/1"])
        XCTAssertEqual(RemovedPhotos.originalNames(defaults), ["shot-1790646372.jpg"])
    }

    // 검토 F2-b: 이 기기 사진을 아직 못 찾은 받은 기록을 빼면 assetID 가 없다 — cloudID 로라도 적어야 ♥ 담기가 막힌다.
    func testTakingOutAnUnresolvedRecordRemembersItsCloudID() {
        let m = unresolved(date(2026, 9, 22, 9), cloud: "C/unresolved")
        store.add(m)

        store.takeOut(m.id, noting: defaults)

        XCTAssertTrue(RemovedPhotos.assetIDs(defaults).isEmpty)
        XCTAssertEqual(RemovedPhotos.cloudIDs(defaults), ["C/unresolved"])
    }

    func testRemovedPhotosRemembersEachPhotoOnce() {
        let m = inPhotos(date(2026, 9, 22, 10), "#2233CC", asset: "L/2")
        RemovedPhotos.note(m, defaults: defaults)
        RemovedPhotos.note(m, defaults: defaults)
        XCTAssertEqual(defaults.stringArray(forKey: RemovedPhotos.assetKey), ["L/2"])
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

    // MARK: 다른 기기에서 뺀 사진 (CloudSync.settleRemoteDeletes 와 같은 순서)

    private func receiveDelete(_ ids: Set<Moment.ID>, now: Date) -> [Moment] {
        let leaving = store.moments.filter { ids.contains($0.id) }
        store.applyRemote(upserts: [], deletes: ids)
        RemovedPhotos.noteGone(leaving, remaining: store.moments, now: now, defaults: defaults)
        return leaving
    }

    func testAPhotoTakenOutOnAnotherDeviceIsRememberedHere() {
        var m = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/here")
        m.cloudID = "C/1"
        store.add(m)

        _ = receiveDelete([m.id], now: date(2026, 9, 22, 20))

        XCTAssertEqual(RemovedPhotos.assetIDs(defaults), ["L/here"])
        XCTAssertEqual(RemovedPhotos.cloudIDs(defaults), ["C/1"])
    }

    // 검토 F2-a: 이 기기가 사진을 찾기 전에 다른 기기가 뺐다 — cloudID 로 적고, ♥ 담기 후보를 cloudID 로 거른다.
    func testAnUnresolvedRecordTakenOutElsewhereIsRememberedByCloudIDAndFiltersCandidates() {
        let m = unresolved(date(2026, 9, 22, 9), cloud: "C/1")
        store.add(m)

        _ = receiveDelete([m.id], now: date(2026, 9, 22, 20))

        XCTAssertEqual(RemovedPhotos.cloudIDs(defaults), ["C/1"])
        let kept = RemovedPhotos.keeping(["L/taken-out", "L/other", "L/no-cloud"],
                                         cloudIDOf: ["L/taken-out": "C/1", "L/other": "C/2"],
                                         removed: RemovedPhotos.cloudIDs(defaults))
        XCTAssertEqual(kept, ["L/other", "L/no-cloud"])
    }

    // 중복을 합치느라 지운 기록 — 같은 사진을 넘겨받은 기록이 남아 있으니 뺀 사진이 아니다.
    func testARemoteDeleteThatHandsThePhotoToATwinIsNotRemembered() {
        let local = Moment(capturedAt: date(2026, 9, 22, 9), colorHex: "#CC3322",
                           fileName: Moment.assetFileName(for: "L/1"), source: .app, assetID: "L/1", cloudID: "C/1")
        let twin = unresolved(date(2026, 9, 22, 9), cloud: "C/1")
        store.add(local)
        store.add(twin)

        _ = receiveDelete([local.id], now: date(2026, 9, 22, 20))

        XCTAssertEqual(store.moments.map(\.assetID), ["L/1"])
        XCTAssertTrue(RemovedPhotos.assetIDs(defaults).isEmpty)
        XCTAssertTrue(RemovedPhotos.cloudIDs(defaults).isEmpty)
    }

    // 검토 F3: 다른 기기의 정리 삭제가 옛 사진을 한꺼번에 지워도 사용자가 뺀 사진이 목록에서 밀리지 않게.
    func testOldPhotosDeletedElsewhereAreNotRemembered() {
        let taken = inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/taken")
        store.add(taken)
        store.takeOut(taken.id, noting: defaults)
        let old = (0...RemovedPhotos.keep).map { inPhotos(date(2026, 9, 1, 9), "#2233CC", asset: "L/old-\($0)") }
        store.add(contentsOf: old)

        _ = receiveDelete(Set(old.map(\.id)), now: date(2026, 9, 22, 20))

        XCTAssertEqual(RemovedPhotos.assetIDs(defaults), ["L/taken"], "알아서 담는 길은 오늘 사진만 본다")
    }

    // 검토 F1: 사진 권한 없는 기기의 파일 — 다른 기기에서 빼면 가리킬 기록이 없어진다. 고아로 남기지 않는다.
    func testAFileOnlyThisDeviceHadIsDeletedWhenAnotherDeviceTakesItOut() async throws {
        let shot = try writeShot()
        let m = Moment(capturedAt: date(2026, 9, 22, 9), colorHex: "#CC3322", fileName: shot.name, source: .locked,
                       originalName: shot.name)
        store.add(m)

        let leaving = receiveDelete([m.id], now: date(2026, 9, 22, 20))
        await store.removeLeftoverFiles(of: leaving)?.value

        XCTAssertFalse(FileManager.default.fileExists(atPath: shot.url.path))
        XCTAssertEqual(RemovedPhotos.originalNames(defaults), [shot.name], "잠금화면 재전달도 막는다")
        XCTAssertTrue(DayStore(fileURL: tempFile, closures: closures).moments.isEmpty)
    }

    func testALeftoverFileStillUsedByAnotherRecordIsKept() async throws {
        let shot = try writeShot()
        let a = Moment(capturedAt: date(2026, 9, 22, 9), colorHex: "#CC3322", fileName: shot.name, source: .app)
        store.add(a)
        store.applyRemote(upserts: [], deletes: [a.id])
        store.add(Moment(capturedAt: date(2026, 9, 22, 9), colorHex: "#CC3322", fileName: shot.name, source: .app))

        await store.removeLeftoverFiles(of: [a])?.value

        XCTAssertTrue(FileManager.default.fileExists(atPath: shot.url.path), "남은 기록이 쓰는 파일")
        XCTAssertNil(store.removeLeftoverFiles(of: [inPhotos(date(2026, 9, 22, 9), "#CC3322", asset: "L/1")]),
                     "자리 이름은 지울 파일이 없다")
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
