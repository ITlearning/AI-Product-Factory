import XCTest
@testable import ColorMoments

@MainActor
final class CaptureInboxTests: XCTestCase {

    private final class Session {
        var urls: [URL] = []
        var invalidated: [URL] = []
        var adopted: [String] = []
    }

    private var root: URL!
    private var sessionDir: URL!
    private var shots: URL!
    private var store: DayStore!
    private var session: Session!

    private let shotName = "shot-1790646372.jpg"

    override func setUp() async throws {
        try await super.setUp()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)")
        sessionDir = root.appendingPathComponent("SecureCapture/6ECCBDF6", isDirectory: true)
        shots = root.appendingPathComponent("Shots", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true)
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "IMG_5005", withExtension: "jpg",
                                                               subdirectory: "Fixtures"))
        try FileManager.default.copyItem(at: fixture, to: sessionDir.appendingPathComponent(shotName))
        store = DayStore(fileURL: root.appendingPathComponent("days.json"),
                         closures: DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        session = Session()
        session.urls = [sessionDir]
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
        try await super.tearDown()
    }

    private func makeInbox() -> CaptureInbox {
        let session = session!
        return CaptureInbox(
            sessionURLs: { session.urls },
            invalidate: { url in
                session.invalidated.append(url)
                session.urls.removeAll { $0 == url }
                try FileManager.default.removeItem(at: url)
            },
            adopt: { m, _ in session.adopted.append(m.fileName) },
            shotsDirectory: shots)
    }

    // 2026-09-29 16 Pro: 세션 목록엔 1개가 있는데 sessionContentUpdates 가 .initial 을 안 보내 사진이 남았다.
    func testSweepIngestsListedSessionWithoutWaitingForTheStream() async {
        let inbox = makeInbox()
        inbox.dayStore = store

        await inbox.sweep()

        XCTAssertEqual(store.moments.count, 1)
        let m = store.moments.first
        XCTAssertEqual(m?.source, .locked)
        XCTAssertEqual(m?.fileName, shotName)
        XCTAssertEqual(m?.capturedAt, Date(timeIntervalSince1970: 1_790_646_372))
        XCTAssertTrue(FileManager.default.fileExists(atPath: shots.appendingPathComponent(shotName).path))
        XCTAssertEqual(session.invalidated, [sessionDir])
        XCTAssertEqual(session.adopted, [shotName])
    }

    // 2026-10-01: 잠금화면 확장이 사진 옆에 위치 쪽지를 두면 들여올 때 붙인다 — 쪽지는 사진으로 들여오지 않는다.
    func testLockedPlaceNoteIsAttachedNotImported() async throws {
        UserDefaults.standard.set(true, forKey: PlaceFinder.enabledKey)
        defer { UserDefaults.standard.removeObject(forKey: PlaceFinder.enabledKey) }
        let note = LockedPlaceNote(latitude: 37.48, longitude: 126.95, accuracy: 65, fixedAt: Date(), authorization: 4)
        try JSONEncoder().encode(note).write(to: LockedPlaceNote.url(for: sessionDir.appendingPathComponent(shotName)))
        let inbox = makeInbox()
        inbox.dayStore = store

        await inbox.sweep()

        XCTAssertEqual(store.moments.count, 1, "쪽지는 사진이 아니다")
        XCTAssertEqual(store.moments.first?.place?.latitude, 37.48)
        XCTAssertEqual(store.moments.first?.place?.longitude, 126.95)
        XCTAssertFalse(FileManager.default.fileExists(atPath: shots.appendingPathComponent("shot-1790646372.place.json").path))
        XCTAssertEqual(UserDefaults.standard.string(forKey: CaptureInbox.lockedPlaceProbeKey), "좌표 받음 ±65m")
    }

    func testNoteWithoutCoordinatesSaysWhy() async throws {
        let note = LockedPlaceNote(authorization: 0, error: "kCLErrorDomain 1")
        try JSONEncoder().encode(note).write(to: LockedPlaceNote.url(for: sessionDir.appendingPathComponent(shotName)))
        let inbox = makeInbox()
        inbox.dayStore = store

        await inbox.sweep()

        XCTAssertNil(store.moments.first?.place)
        XCTAssertEqual(UserDefaults.standard.string(forKey: CaptureInbox.lockedPlaceProbeKey), "좌표 없음 — 권한 미정 · kCLErrorDomain 1")
    }

    // 앱 시작(.task)과 active 전환이 같은 세션을 동시에 쓸어 간다 — 무효화·입양은 한 번뿐이어야 한다.
    func testOverlappingSweepsIngestOnce() async {
        let inbox = makeInbox()
        inbox.dayStore = store

        async let first: Void = inbox.sweep()
        async let second: Void = inbox.sweep()
        _ = await (first, second)
        await inbox.sweep()

        XCTAssertEqual(store.moments.count, 1)
        XCTAssertEqual(session.invalidated.count, 1)
        XCTAssertEqual(session.adopted, [shotName])
    }

    // 저장소가 꽂히기 전 active 가 먼저 오면 기록 없이 원본만 지워질 수 있었다.
    func testSweepBeforeStoreIsAttachedLeavesSessionUntouched() async {
        let inbox = makeInbox()

        await inbox.sweep()

        XCTAssertTrue(session.invalidated.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionDir.appendingPathComponent(shotName).path))

        inbox.dayStore = store
        await inbox.sweep()
        XCTAssertEqual(store.moments.count, 1)
        XCTAssertEqual(session.invalidated, [sessionDir])
    }
}
