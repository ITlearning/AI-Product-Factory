import XCTest
@testable import ColorMoments

@MainActor
final class DayStoreLoadTests: XCTestCase {

    private var tempFile: URL!
    private var closures: DayClosures!

    override func setUp() {
        super.setUp()
        tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("load-\(UUID().uuidString).json")
        closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFile)
        super.tearDown()
    }

    private func seed(_ n: Int) -> [Moment] {
        let store = DayStore(fileURL: tempFile, closures: closures)
        let start = Date().addingTimeInterval(-30 * 86_400)
        let ms = (0..<n).map { i in
            Moment(capturedAt: start.addingTimeInterval(Double(i) * 3_600), colorHex: "#445566",
                   fileName: "s\(i)", source: .library, addedAt: start, cloudID: "C\(i)")
        }
        store.applyRemote(upserts: ms, deletes: [])
        store.flush()
        return store.moments
    }

    func testBackgroundLoadFillsSameMomentsAsSyncLoad() async {
        let seeded = seed(300)
        let store = DayStore(fileURL: tempFile, closures: closures, loadsInBackground: true)
        XCTAssertFalse(store.isLoaded)
        XCTAssertTrue(store.moments.isEmpty)
        await store.waitUntilLoaded()
        XCTAssertTrue(store.isLoaded)
        XCTAssertEqual(store.moments, DayStore(fileURL: tempFile, closures: closures).moments)
        XCTAssertEqual(store.moments.count, seeded.count)
    }

    /// 로드 전에 찍은 한 장이 디스크의 전체 기록을 덮어쓰지 않고 뒤에 붙는다.
    func testAddBeforeLoadIsKeptAndDoesNotClobberFile() async {
        _ = seed(50)
        let store = DayStore(fileURL: tempFile, closures: closures, loadsInBackground: true)
        var changes: [StoreChange] = []
        store.onLocalChange = { changes += $0 }
        let early = Moment(capturedAt: Date(), colorHex: "#FFFFFF", fileName: "early.jpg", source: .app)
        XCTAssertTrue(store.add(early))
        store.flush()
        XCTAssertEqual(DayStore(fileURL: tempFile, closures: closures).moments.count, 50,
                       "로드 전 저장은 미뤄져야 한다")
        await store.waitUntilLoaded()
        XCTAssertEqual(store.moments.count, 51)
        XCTAssertEqual(store.moments.last?.id, early.id)
        XCTAssertEqual(changes, [.upsert(early.id)])
        store.flush()
        XCTAssertEqual(DayStore(fileURL: tempFile, closures: closures).moments.count, 51)
    }

    func testMissingFileLoadsEmpty() async {
        let store = DayStore(fileURL: tempFile, closures: closures, loadsInBackground: true)
        await store.waitUntilLoaded()
        XCTAssertTrue(store.isLoaded)
        XCTAssertTrue(store.moments.isEmpty)
    }
}
