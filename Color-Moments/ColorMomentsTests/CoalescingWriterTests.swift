import XCTest
@testable import ColorMoments

final class CoalescingWriterTests: XCTestCase {

    private func tempURL(_ name: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// 동기화 토큰은 받은 기록이 디스크에 남은 뒤에만 써야 한다 — 거꾸로면 kill 뒤 그 기록을 다시 받지 못한다.
    func testThenRunsAfterPendingWriteLandsOnDisk() {
        let url = tempURL("then")
        let writer = CoalescingWriter.forFile(url)
        writer.write { Thread.sleep(forTimeInterval: 0.2); return Data("A".utf8) }
        let seen = LockedBox<String?>(nil)
        writer.then { seen.set((try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }) }
        writer.flush()
        XCTAssertEqual(seen.get(), "A")
    }

    func testDayStoreAfterSavedSeesLatestMoments() {
        let url = tempURL("days")
        let closures = DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let store = DayStore(fileURL: url, closures: closures)
        store.add(Moment(capturedAt: Date(), colorHex: "#112233", fileName: "a.jpg", source: .app))
        store.add(Moment(capturedAt: Date(), colorHex: "#112233", fileName: "b.jpg", source: .app))
        let count = LockedBox<Int>(-1)
        store.afterSaved {
            let data = (try? Data(contentsOf: url)) ?? Data()
            let list = (try? JSONSerialization.jsonObject(with: data)) as? [Any]
            count.set(list?.count ?? 0)
        }
        store.flush()
        XCTAssertEqual(count.get(), 2)
    }

    /// 여러 파일을 순서대로 이어 쓸 때 — 앞 파일 큐가 끝난 뒤 뒤 파일 큐에 넣는다.
    func testChainedThenAcrossWritersKeepsOrder() {
        let a = CoalescingWriter.forFile(tempURL("a"))
        let b = CoalescingWriter.forFile(tempURL("b"))
        let order = LockedBox<[String]>([])
        a.write { Thread.sleep(forTimeInterval: 0.1); order.update { $0.append("a") }; return Data() }
        b.write { order.update { $0.append("b") }; return Data() }
        a.then { b.then { order.update { $0.append("state") } } }
        a.flush()
        b.flush()
        XCTAssertEqual(order.get().last, "state")
        XCTAssertEqual(Set(order.get()), ["a", "b", "state"])
    }
}

final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T
    init(_ value: T) { self.value = value }
    func get() -> T { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ v: T) { lock.lock(); value = v; lock.unlock() }
    func update(_ f: (inout T) -> Void) { lock.lock(); f(&value); lock.unlock() }
}
