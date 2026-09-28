import CoreLocation
import Photos
import XCTest
@testable import ColorMoments

@MainActor
final class AssetAdopterTests: XCTestCase {

    private final class Fake {
        var status: PHAuthorizationStatus = .authorized
        var found: Set<String> = []
        var onDisk: Set<String> = []
        var cloudToLocal: [String: String] = [:]
        var nextID: String? = "NEW"
        var saved: [String] = []
        var removed: [String] = []
        var mapped = 0
        var saveGate: (() async -> Void)?

        var env: AssetAdopter.Env {
            AssetAdopter.Env(
                access: { self.status },
                save: { url, _, _ in
                    self.saved.append(url.lastPathComponent)
                    await self.saveGate?()
                    var report = AssetSaver.Report(fileName: url.lastPathComponent)
                    report.attempts = [.init(method: .file, error: self.nextID == nil ? "PHPhotosErrorDomain 3302: 실패" : nil)]
                    report.assetID = self.nextID
                    return report
                },
                existing: { ids in Set(ids).intersection(self.found) },
                localIDs: { clouds in self.cloudToLocal.filter { clouds.contains($0.key) } },
                localFiles: { names in Set(names).intersection(self.onDisk) },
                removeFile: { self.removed.append($0.lastPathComponent) },
                assignMissing: { _ in self.mapped += 1 }
            )
        }
    }

    private var tempFile: URL!
    private var store: DayStore!

    override func setUp() async throws {
        tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("adopt-\(UUID().uuidString).json")
        store = DayStore(fileURL: tempFile, closures: DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        store.onLocalChange = { _ in }
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempFile)
    }

    private func moment(_ name: String, asset: String?, cloud: String? = nil, original: String? = nil) -> Moment {
        Moment(capturedAt: Date(), colorHex: "#445566", fileName: name, source: .app, assetID: asset,
               originalName: original, cloudID: cloud)
    }

    func testAdoptAllDoesNotBringBackDeletedAssetsFromLeftoverFile() async {
        store.add(moment("library-a.jpg", asset: "OLD", cloud: "C-OLD")); store.add(moment("asset-b", asset: "B"))
        let fake = Fake()
        fake.found = ["B"]; fake.onDisk = ["library-a.jpg"]

        await AssetAdopter.adoptAll(store: store, env: fake.env)

        XCTAssertTrue(fake.saved.isEmpty, "사진 앱에서 지운 사진은 사본이 남아도 자동으로 되살리지 않는다")
        XCTAssertTrue(fake.removed.isEmpty, "사본 파일은 정리가 기록을 지운 뒤에 치운다")
    }

    // MARK: 수동 복구(디버그 전용)

    func testRestoreSavesAgainAndRemovesFileAfterSwap() async {
        let lost = moment("shot-a.jpg", asset: "OLD", cloud: "C-OLD", original: "IMG_1.HEIC")
        let fine = moment("asset-b", asset: "B")
        store.add(lost); store.add(fine)
        let fake = Fake()
        fake.found = ["B"]
        fake.onDisk = ["shot-a.jpg"]

        let restored = await AssetAdopter.restoreLost(store: store, env: fake.env)

        XCTAssertEqual(restored, 1)
        let r = store.moments.first { $0.id == lost.id }
        XCTAssertEqual(r?.assetID, "NEW")
        XCTAssertEqual(r?.fileName, Moment.assetFileName(for: "NEW"))
        XCTAssertEqual(r?.originalName, "IMG_1.HEIC")
        XCTAssertNil(r?.cloudID)
        XCTAssertEqual(fake.saved, ["shot-a.jpg"])
        XCTAssertEqual(fake.removed, ["shot-a.jpg"], "새 ID 로 바꾼 뒤에만 파일을 지운다")
        XCTAssertEqual(fake.mapped, 1, "새 사진의 cloudID 를 붙인다")
    }

    func testRestoreStopsAtLimit() async {
        for i in 0..<3 { store.add(moment("shot-\(i).jpg", asset: "OLD\(i)")) }
        store.add(moment("asset-b", asset: "B"))
        let fake = Fake()
        fake.found = ["B"]; fake.onDisk = ["shot-0.jpg", "shot-1.jpg", "shot-2.jpg"]

        let restored = await AssetAdopter.restoreLost(store: store, limit: 2, env: fake.env)

        XCTAssertEqual(restored, 2)
        XCTAssertEqual(fake.saved.count, 2, "한 번에 상한까지만 다시 저장한다")
    }

    func testFileBackedMomentIsStillAdopted() async {
        let file = moment("shot-f.jpg", asset: nil)
        store.add(file)
        let fake = Fake()

        await AssetAdopter.adoptAll(store: store, env: fake.env)

        XCTAssertEqual(store.moments.first?.assetID, "NEW")
        XCTAssertEqual(fake.removed, ["shot-f.jpg"])
    }

    func testFailedSaveKeepsRecordAndFile() async {
        let lost = moment("shot-a.jpg", asset: "OLD")
        store.add(lost); store.add(moment("asset-b", asset: "B"))
        let fake = Fake()
        fake.found = ["B"]; fake.onDisk = ["shot-a.jpg"]; fake.nextID = nil

        await AssetAdopter.restoreLost(store: store, env: fake.env)

        XCTAssertEqual(store.moments.first { $0.id == lost.id }?.assetID, "OLD")
        XCTAssertTrue(fake.removed.isEmpty, "저장에 실패하면 파일이 유일한 사본이다")
    }

    func testLimitedAccessDoesNotSaveAgain() async {
        store.add(moment("shot-a.jpg", asset: "OLD")); store.add(moment("asset-b", asset: "B"))
        let fake = Fake()
        fake.status = .limited; fake.found = ["B"]; fake.onDisk = ["shot-a.jpg"]

        await AssetAdopter.restoreLost(store: store, env: fake.env)

        XCTAssertTrue(fake.saved.isEmpty, "제한 접근에서 못 찾은 건 고르지 않은 사진일 뿐 — 다시 저장하면 중복된다")
    }

    func testEmptyLookupDoesNotSaveAgain() async {
        store.add(moment("shot-a.jpg", asset: "OLD")); store.add(moment("shot-b.jpg", asset: "B"))
        let fake = Fake()
        fake.onDisk = ["shot-a.jpg", "shot-b.jpg"]

        await AssetAdopter.restoreLost(store: store, env: fake.env)

        XCTAssertTrue(fake.saved.isEmpty, "조회가 통째로 비면 실패일 수 있다 — 전부 다시 저장하면 사진 앱이 중복으로 찬다")
    }

    func testRelocatableByCloudIDIsLeftToReconciler() async {
        store.add(moment("shot-a.jpg", asset: "OLD", cloud: "C-A")); store.add(moment("asset-b", asset: "B"))
        let fake = Fake()
        fake.found = ["B"]; fake.onDisk = ["shot-a.jpg"]; fake.cloudToLocal = ["C-A": "MOVED"]

        await AssetAdopter.restoreLost(store: store, env: fake.env)

        XCTAssertTrue(fake.saved.isEmpty, "cloudID 로 다시 찾아지면 정리가 바꿔 끼운다 — 다시 저장하면 중복")
    }

    func testMissingFileIsNotSavedAgain() async {
        store.add(moment("shot-a.jpg", asset: "OLD")); store.add(moment("asset-b", asset: "B"))
        let fake = Fake()
        fake.found = ["B"]

        await AssetAdopter.restoreLost(store: store, env: fake.env)

        XCTAssertTrue(fake.saved.isEmpty)
    }

    func testConcurrentAdoptAllSavesOnce() async {
        store.add(moment("shot-a.jpg", asset: nil))
        let fake = Fake()
        fake.saveGate = { await Task.yield() }

        async let first: Void = AssetAdopter.adoptAll(store: store, env: fake.env)
        async let second: Void = AssetAdopter.adoptAll(store: store, env: fake.env)
        _ = await (first, second)
        await AssetAdopter.adoptAll(store: store, env: fake.env)

        XCTAssertEqual(fake.saved, ["shot-a.jpg"], "같은 사진이 두 번 저장되면 사진 앱에 중복이 생긴다")
    }

    func testConcurrentRestoreSavesOnce() async {
        store.add(moment("shot-a.jpg", asset: "OLD")); store.add(moment("asset-b", asset: "B"))
        let fake = Fake()
        fake.found = ["B"]; fake.onDisk = ["shot-a.jpg"]
        fake.saveGate = { await Task.yield() }

        async let first = AssetAdopter.restoreLost(store: store, env: fake.env)
        async let second = AssetAdopter.restoreLost(store: store, env: fake.env)
        _ = await (first, second)

        XCTAssertEqual(fake.saved, ["shot-a.jpg"], "같은 사진이 두 번 저장되면 사진 앱에 중복이 생긴다")
    }

    func testFailedSaveIsRecordedForDiagnostics() async {
        let before = AssetAdopter.stats
        store.add(moment("shot-a.jpg", asset: "OLD")); store.add(moment("asset-b", asset: "B"))
        store.add(moment("shot-f.jpg", asset: nil))
        let fake = Fake()
        fake.found = ["B"]; fake.onDisk = ["shot-a.jpg"]; fake.nextID = nil

        await AssetAdopter.adoptAll(store: store, env: fake.env)

        let after = AssetAdopter.stats
        XCTAssertEqual(after.readoptTried, before.readoptTried, "자동 입양은 사라진 사진을 다시 저장하지 않는다")
        XCTAssertEqual(after.adoptTried - before.adoptTried, 1)
        XCTAssertEqual(after.adoptSucceeded, before.adoptSucceeded)
        XCTAssertEqual(after.lastFailure?.fileName, "shot-f.jpg")
        XCTAssertEqual(after.lastFailure?.attempts.first?.error, "PHPhotosErrorDomain 3302: 실패")
    }

    // MARK: 저장 대안 경로

    private struct Boom: Error {}

    func testSaverFallsBackInOrderAndStopsAtFirstSuccess() async {
        var ran: [AssetSaver.Method] = []
        let report = await AssetSaver.run(fileName: "old.jpg", attempts: [
            (.file, { ran.append(.file); throw NSError(domain: "PHPhotosErrorDomain", code: 3300) }),
            (.data, { ran.append(.data); return "ID-2" }),
            (.reencoded, { ran.append(.reencoded); return "ID-3" }),
        ])
        XCTAssertEqual(ran, [.file, .data], "성공하면 다음 방법은 시도하지 않는다")
        XCTAssertEqual(report.assetID, "ID-2")
        XCTAssertEqual(report.attempts.map(\.method), [.file, .data])
        XCTAssertTrue(report.attempts[0].error?.hasPrefix("PHPhotosErrorDomain 3300") == true, "도메인·코드가 남아야 원인을 좁힌다")
        XCTAssertNil(report.attempts[1].error)
        XCTAssertFalse(report.failed)
    }

    func testSaverRecordsEveryFailedAttempt() async {
        let report = await AssetSaver.run(fileName: "old.jpg", attempts: [
            (.file, { throw Boom() }), (.data, { throw Boom() }), (.reencoded, { throw AssetSaver.Undecodable() }),
        ])
        XCTAssertTrue(report.failed)
        XCTAssertEqual(report.attempts.count, 3)
        XCTAssertTrue(report.attempts[2].error?.contains("이미지로 읽을 수 없음") == true)
        XCTAssertTrue(report.summary.hasPrefix("old.jpg: 파일 경로 "))
    }

    func testSaverDoesNotRetryAfterNoPlaceholder() async {
        var ran: [AssetSaver.Method] = []
        let report = await AssetSaver.run(fileName: "old.jpg", attempts: [
            (.file, { ran.append(.file); throw AssetSaver.NoPlaceholder() }),
            (.data, { ran.append(.data); return "ID-2" }),
        ])
        XCTAssertEqual(ran, [.file], "커밋 뒤 실패는 사진이 이미 생겼을 수 있다 — 다시 저장하면 중복")
        XCTAssertTrue(report.failed)
        XCTAssertEqual(report.attempts.first?.error, "placeholder 없음")
    }

    func testSaverUsesAssetFoundAfterNoPlaceholder() async {
        let report = await AssetSaver.run(fileName: "old.jpg", attempts: [
            (.file, { throw AssetSaver.NoPlaceholder() }),
            (.data, { XCTFail("다시 저장하면 안 된다"); return "ID-2" }),
        ], findRecent: { "MADE" })
        XCTAssertEqual(report.assetID, "MADE")
        XCTAssertEqual(report.attempts.map(\.method), [.file, .existing])
    }

    func testSaverChecksForCreatedAssetBeforeNextAttempt() async {
        var ran: [AssetSaver.Method] = []
        var lookups = 0
        let report = await AssetSaver.run(fileName: "old.jpg", attempts: [
            (.file, { ran.append(.file); throw Boom() }),
            (.data, { ran.append(.data); return "ID-2" }),
        ], findRecent: { lookups += 1; return "MADE" })
        XCTAssertEqual(ran, [.file], "앞 시도가 사진을 남겼으면 다음 방법으로 또 저장하지 않는다")
        XCTAssertEqual(lookups, 1, "첫 시도 전엔 찾지 않는다")
        XCTAssertEqual(report.assetID, "MADE")
        XCTAssertEqual(report.attempts.map(\.method), [.file, .existing])
        XCTAssertTrue(report.summary.hasSuffix("이미 생긴 사진 성공"))
    }

    func testSaverMovesOnWhenNothingWasCreated() async {
        var lookups = 0
        let report = await AssetSaver.run(fileName: "old.jpg", attempts: [
            (.file, { throw Boom() }), (.data, { throw Boom() }), (.reencoded, { "ID-3" }),
        ], findRecent: { lookups += 1; return nil })
        XCTAssertEqual(lookups, 2)
        XCTAssertEqual(report.assetID, "ID-3")
    }

    func testFoundAssetAlreadyUsedByAnotherRecordIsRejected() {
        store.add(moment("asset-b", asset: "B"))
        var report = AssetSaver.Report(fileName: "shot-a.jpg", assetID: "B")
        report.attempts = [.init(method: .file, error: "x"), .init(method: .existing, error: nil)]
        let checked = AssetAdopter.unclaimed(report, store: store)
        XCTAssertTrue(checked.failed, "같은 초에 찍은 다른 기록의 사진을 가져다 쓰면 안 된다")
        var fresh = report
        fresh.assetID = "C"
        XCTAssertEqual(AssetAdopter.unclaimed(fresh, store: store).assetID, "C")
    }

    func testSaverReportsMissingFileWithoutTrying() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("none-\(UUID().uuidString).jpg")
        let report = await AssetSaver.save(fileURL: url, creationDate: Date(), location: nil)
        XCTAssertTrue(report.fileMissing)
        XCTAssertTrue(report.failed)
        XCTAssertTrue(report.attempts.isEmpty)
    }
}
