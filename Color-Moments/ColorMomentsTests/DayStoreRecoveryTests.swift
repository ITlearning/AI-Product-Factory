import XCTest
@testable import ColorMoments

/// days.json 이 일부·전부 망가져도 읽을 수 있는 기록은 살리고, 원본은 복사해 두고, 빈 목록으로 덮어쓰지 않는다.
@MainActor
final class DayStoreRecoveryTests: XCTestCase {

    private var dir: URL!
    private var file: URL { dir.appendingPathComponent("days.json") }
    private var closures: DayClosures!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("recovery-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func backups() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("days.json.corrupt-") }
    }

    /// 3개를 저장한 뒤 가운데 원소의 날짜를 망가뜨린 파일.
    private func writeOneBroken() throws -> Data {
        let store = DayStore(fileURL: file, closures: closures)
        let base = Date(timeIntervalSince1970: 1_780_000_000)
        for i in 0..<3 {
            store.add(Moment(capturedAt: base.addingTimeInterval(Double(i) * 60), colorHex: "#11223\(i)",
                             fileName: "f\(i).jpg", source: .app))
        }
        store.flush()
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [[String: Any]])
        json[1]["capturedAt"] = "망가진 날짜"
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: file)
        return data
    }

    func testOneBrokenRecordKeepsTheRestAndBacksUp() throws {
        let original = try writeOneBroken()
        let store = DayStore(fileURL: file, closures: closures)
        XCTAssertEqual(store.moments.map(\.fileName), ["f0.jpg", "f2.jpg"])
        XCTAssertEqual(store.loadIssue, .partial(skipped: 1))
        XCTAssertFalse(store.isSaveBlocked)
        let b = backups()
        XCTAssertEqual(b.count, 1)
        XCTAssertEqual(try Data(contentsOf: b[0]), original, "백업은 손대기 전 원본 그대로")
    }

    func testOneBrokenRecordBackgroundLoadAlsoBacksUp() async throws {
        _ = try writeOneBroken()
        let store = DayStore(fileURL: file, closures: closures, loadsInBackground: true)
        await store.waitUntilLoaded()
        XCTAssertEqual(store.moments.count, 2)
        XCTAssertEqual(backups().count, 1)
    }

    func testUnreadableFileIsBackedUpAndNeverOverwrittenWithEmpty() async throws {
        let garbage = Data("{\"이건\": 배열이 아니다".utf8)
        try garbage.write(to: file)
        let store = DayStore(fileURL: file, closures: closures, loadsInBackground: true)
        await store.waitUntilLoaded()
        XCTAssertTrue(store.isLoaded)
        XCTAssertTrue(store.moments.isEmpty)
        XCTAssertEqual(store.loadIssue, .unreadable)
        XCTAssertTrue(store.isSaveBlocked)
        XCTAssertEqual(backups().count, 1)

        // 빈 목록 저장을 부르는 경로(지울 게 없는 remove·빈 원격 적용 등)가 돌아도 파일은 그대로.
        store.applyRemote(upserts: [], deletes: [UUID()])
        store.resolveAssets([])
        store.flush()
        XCTAssertEqual(try Data(contentsOf: file), garbage)
    }

    /// 완전 손상이어도 새로 찍은 기록은 백업이 남아 있으니 저장한다 — 안 그러면 새 기록이 사라진다.
    func testNewRecordAfterUnreadableIsSavedOnceBackupExists() async throws {
        try Data("망가짐".utf8).write(to: file)
        let store = DayStore(fileURL: file, closures: closures, loadsInBackground: true)
        let early = Moment(capturedAt: Date(), colorHex: "#FFFFFF", fileName: "early.jpg", source: .app)
        store.add(early)
        await store.waitUntilLoaded()
        XCTAssertFalse(store.isSaveBlocked)
        store.flush()
        XCTAssertEqual(backups().count, 1)
        XCTAssertEqual(DayStore(fileURL: file, closures: closures).moments.map(\.id), [early.id])
    }

    func testHealthyFileHasNoIssueAndNoBackup() {
        let store = DayStore(fileURL: file, closures: closures)
        store.add(Moment(capturedAt: Date(), colorHex: "#000000", fileName: "ok.jpg", source: .app))
        store.flush()
        let reopened = DayStore(fileURL: file, closures: closures)
        XCTAssertNil(reopened.loadIssue)
        XCTAssertEqual(reopened.moments.count, 1)
        XCTAssertTrue(backups().isEmpty)
    }
    /// 첫 잠금 해제 전 파일 보호처럼 읽기 자체가 실패하는 상황을 흉내 낸다.
    private final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var open = false
        func unlock() { lock.withLock { open = true } }
        func read(_ url: URL) throws -> Data {
            guard lock.withLock({ open }) else { throw CocoaError(.fileReadNoPermission) }
            return try Data(contentsOf: url)
        }
    }

    private func seedTwo() throws -> [Moment] {
        let store = DayStore(fileURL: file, closures: closures)
        let base = Date(timeIntervalSince1970: 1_780_000_000)
        for i in 0..<2 {
            store.add(Moment(capturedAt: base.addingTimeInterval(Double(i) * 60), colorHex: "#22334\(i)",
                             fileName: "s\(i).jpg", source: .app))
        }
        store.flush()
        return store.moments
    }

    /// 못 읽은 건 손상이 아니다 — 백업·저장 차단 없이 로드 전으로 남고, 풀리면 읽은 기록 + 그 사이 추가분을 쓴다.
    func testReadFailureDefersSaveAndRetryWritesLoadedPlusEarly() async throws {
        let seeded = try seedTwo()
        let original = try Data(contentsOf: file)
        let gate = Gate()
        let store = DayStore(fileURL: file, closures: closures, readData: { try gate.read($0) })
        XCTAssertFalse(store.isLoaded)
        XCTAssertNil(store.loadIssue)
        XCTAssertFalse(store.isSaveBlocked)

        let early = Moment(capturedAt: Date(), colorHex: "#ABCDEF", fileName: "early.jpg", source: .app)
        store.add(early)
        store.flush()
        XCTAssertEqual(try Data(contentsOf: file), original, "로드 전엔 디스크를 덮지 않는다")
        XCTAssertTrue(backups().isEmpty)

        await store.retryLoadIfNeeded()
        XCTAssertFalse(store.isLoaded, "아직 잠겨 있으면 계속 로드 전")
        XCTAssertEqual(try Data(contentsOf: file), original)

        gate.unlock()
        await store.retryLoadIfNeeded()
        XCTAssertTrue(store.isLoaded)
        XCTAssertEqual(store.moments.map(\.id), seeded.map(\.id) + [early.id])
        store.flush()
        XCTAssertEqual(DayStore(fileURL: file, closures: closures).moments.map(\.id), seeded.map(\.id) + [early.id])
        XCTAssertTrue(backups().isEmpty)
    }

    func testBackgroundReadFailureWaitsForRetry() async throws {
        let seeded = try seedTwo()
        let gate = Gate()
        let store = DayStore(fileURL: file, closures: closures, loadsInBackground: true, readData: { try gate.read($0) })
        await store.retryLoadIfNeeded()
        XCTAssertFalse(store.isLoaded)
        XCTAssertNil(store.loadIssue)

        let marker = Marker()
        store.afterSaved { marker.hit() }
        gate.unlock()
        await store.retryLoadIfNeeded()
        XCTAssertTrue(store.isLoaded)
        XCTAssertEqual(store.moments.map(\.id), seeded.map(\.id))
        store.flush()
        XCTAssertTrue(marker.wasHit, "로드 전에 맡긴 뒤따르는 일은 로드 뒤에 돈다")
    }

    /// 저장이 막혀 기록이 디스크에 없으면 뒤따르는 일(동기화 토큰 쓰기)도 돌지 않는다.
    func testAfterSavedIsDroppedWhileSaveBlocked() async throws {
        try Data("{\"이건\": 배열이 아니다".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path) }
        let store = DayStore(fileURL: file, closures: closures)
        XCTAssertEqual(store.loadIssue, .unreadable)
        XCTAssertNil(store.corruptBackupURL)
        XCTAssertTrue(store.isSaveBlocked)
        let marker = Marker()
        store.afterSaved { marker.hit() }
        store.flush()
        XCTAssertFalse(marker.wasHit)
    }

    private final class Marker: @unchecked Sendable {
        private let lock = NSLock()
        private var hits = 0
        func hit() { lock.withLock { hits += 1 } }
        var wasHit: Bool { lock.withLock { hits > 0 } }
    }
}
