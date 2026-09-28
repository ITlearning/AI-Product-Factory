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
                    return self.nextID
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

    func testLostAssetWithLocalFileIsSavedAgainAndFileRemovedAfterSwap() async {
        let lost = moment("shot-a.jpg", asset: "OLD", cloud: "C-OLD", original: "IMG_1.HEIC")
        let fine = moment("asset-b", asset: "B")
        store.add(lost); store.add(fine)
        let fake = Fake()
        fake.found = ["B"]
        fake.onDisk = ["shot-a.jpg"]

        await AssetAdopter.adoptAll(store: store, env: fake.env)

        let r = store.moments.first { $0.id == lost.id }
        XCTAssertEqual(r?.assetID, "NEW")
        XCTAssertEqual(r?.fileName, Moment.assetFileName(for: "NEW"))
        XCTAssertEqual(r?.originalName, "IMG_1.HEIC")
        XCTAssertNil(r?.cloudID)
        XCTAssertEqual(fake.saved, ["shot-a.jpg"])
        XCTAssertEqual(fake.removed, ["shot-a.jpg"], "새 ID 로 바꾼 뒤에만 파일을 지운다")
        XCTAssertEqual(fake.mapped, 1, "새 사진의 cloudID 를 붙인다")
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

        await AssetAdopter.adoptAll(store: store, env: fake.env)

        XCTAssertEqual(store.moments.first { $0.id == lost.id }?.assetID, "OLD")
        XCTAssertTrue(fake.removed.isEmpty, "저장에 실패하면 파일이 유일한 사본이다")
    }

    func testLimitedAccessDoesNotSaveAgain() async {
        store.add(moment("shot-a.jpg", asset: "OLD")); store.add(moment("asset-b", asset: "B"))
        let fake = Fake()
        fake.status = .limited; fake.found = ["B"]; fake.onDisk = ["shot-a.jpg"]

        await AssetAdopter.adoptAll(store: store, env: fake.env)

        XCTAssertTrue(fake.saved.isEmpty, "제한 접근에서 못 찾은 건 고르지 않은 사진일 뿐 — 다시 저장하면 중복된다")
    }

    func testEmptyLookupDoesNotSaveAgain() async {
        store.add(moment("shot-a.jpg", asset: "OLD")); store.add(moment("shot-b.jpg", asset: "B"))
        let fake = Fake()
        fake.onDisk = ["shot-a.jpg", "shot-b.jpg"]

        await AssetAdopter.adoptAll(store: store, env: fake.env)

        XCTAssertTrue(fake.saved.isEmpty, "조회가 통째로 비면 실패일 수 있다 — 전부 다시 저장하면 사진 앱이 중복으로 찬다")
    }

    func testRelocatableByCloudIDIsLeftToReconciler() async {
        store.add(moment("shot-a.jpg", asset: "OLD", cloud: "C-A")); store.add(moment("asset-b", asset: "B"))
        let fake = Fake()
        fake.found = ["B"]; fake.onDisk = ["shot-a.jpg"]; fake.cloudToLocal = ["C-A": "MOVED"]

        await AssetAdopter.adoptAll(store: store, env: fake.env)

        XCTAssertTrue(fake.saved.isEmpty, "cloudID 로 다시 찾아지면 정리가 바꿔 끼운다 — 다시 저장하면 중복")
    }

    func testMissingFileIsNotSavedAgain() async {
        store.add(moment("shot-a.jpg", asset: "OLD")); store.add(moment("asset-b", asset: "B"))
        let fake = Fake()
        fake.found = ["B"]

        await AssetAdopter.adoptAll(store: store, env: fake.env)

        XCTAssertTrue(fake.saved.isEmpty)
    }

    func testConcurrentAdoptAllSavesOnce() async {
        store.add(moment("shot-a.jpg", asset: "OLD")); store.add(moment("asset-b", asset: "B"))
        let fake = Fake()
        fake.found = ["B"]; fake.onDisk = ["shot-a.jpg"]
        fake.saveGate = { await Task.yield() }

        async let first: Void = AssetAdopter.adoptAll(store: store, env: fake.env)
        async let second: Void = AssetAdopter.adoptAll(store: store, env: fake.env)
        _ = await (first, second)
        await AssetAdopter.adoptAll(store: store, env: fake.env)

        XCTAssertEqual(fake.saved, ["shot-a.jpg"], "같은 사진이 두 번 저장되면 사진 앱에 중복이 생긴다")
    }
}
