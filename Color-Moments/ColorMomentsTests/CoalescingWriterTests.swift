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

    /// 백그라운드로 가며 멈춰도 밀린 쓰기가 끝날 때까지 프로세스를 붙잡고, 끝나면 반드시 놓는다.
    func testEveryDrainHoldsAndReleasesActivity() {
        let begun = LockedBox(0), released = LockedBox(0), heldDuringWrite = LockedBox(false)
        let original = CoalescingWriter.activityHolder
        defer { CoalescingWriter.activityHolder = original }
        CoalescingWriter.activityHolder = { _ in
            begun.update { $0 += 1 }
            return { released.update { $0 += 1 } }
        }
        let writer = CoalescingWriter.forFile(tempURL("hold"))
        // 밀린 쓰기는 마지막 것만 돈다 — 둘 다에서 잰다.
        writer.write { heldDuringWrite.set(begun.get() > released.get()); return Data("1".utf8) }
        writer.write { heldDuringWrite.set(begun.get() > released.get()); return Data("2".utf8) }
        writer.then {}
        writer.flush()
        XCTAssertTrue(heldDuringWrite.get(), "쓰는 동안 붙잡고 있어야 한다")
        XCTAssertGreaterThan(begun.get(), 0)
        XCTAssertEqual(begun.get(), released.get(), "붙잡은 만큼 놓아야 한다 — 안 놓으면 시스템이 앱을 죽인다")
    }

    func testFlushReportsFailedWriteUntilNextSuccess() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("nodir-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let writer = CoalescingWriter.forFile(dir.appendingPathComponent("x.json"))
        writer.write { Data("A".utf8) }
        XCTAssertFalse(writer.flush(), "폴더가 없어 못 썼다 — 호출부가 파일을 지우면 안 된다")
        XCTAssertFalse(writer.flush(), "밀린 게 없어도 마지막 실패는 그대로 알린다")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        writer.write { Data("B".utf8) }
        XCTAssertTrue(writer.flush())
    }

    @MainActor
    func testFlushAfterLoadIsFalseWhenWriteFails() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("nodir-\(UUID().uuidString)")
        let store = DayStore(fileURL: dir.appendingPathComponent("days.json"),
                             closures: DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        store.add(Moment(capturedAt: Date(), colorHex: "#112233", fileName: "a.jpg", source: .app))
        let written = await store.flushAfterLoad()
        XCTAssertFalse(written)
    }

    /// 입양·가져오기는 이 답을 보고 원본을 지운다 — 쓰기가 디스크에 닿기 전에 답하면 안 되고, 기다리는 동안 메인은 풀려 있어야 한다.
    @MainActor
    func testFlushedAnswersOnlyAfterPendingWriteLands() async throws {
        let url = tempURL("flushed")
        let writer = CoalescingWriter.forFile(url)
        let gate = DispatchSemaphore(value: 0)
        // 메인을 막는 구현으로 돌아가면 아래 signal 에 영영 못 닿는다 — 멈추지 않고 실패하게.
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { gate.signal() }
        writer.write { gate.wait(); return Data("A".utf8) }
        let answered = LockedBox(false)
        let flushing = Task { @MainActor () -> Bool in
            let ok = await writer.flushed()
            answered.set(true)
            return ok
        }
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertFalse(answered.get(), "쓰기가 끝나기 전에 답이 왔거나 메인이 막혔다")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        gate.signal()
        let ok = await flushing.value
        XCTAssertTrue(ok)
        XCTAssertEqual((try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }, "A")
    }

    func testFlushedReportsFailedWriteUntilNextSuccess() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("nodir-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let writer = CoalescingWriter.forFile(dir.appendingPathComponent("x.json"))
        writer.write { Data("A".utf8) }
        let failed = await writer.flushed()
        XCTAssertFalse(failed, "폴더가 없어 못 썼다 — 호출부가 파일을 지우면 안 된다")
        let stillFailed = await writer.flushed()
        XCTAssertFalse(stillFailed, "밀린 게 없어도 마지막 실패는 그대로 알린다")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        writer.write { Data("B".utf8) }
        let written = await writer.flushed()
        XCTAssertTrue(written)
    }

    func testFlushReportsFailureWhenEncodingFails() async {
        let writer = CoalescingWriter.forFile(tempURL("unencodable"))
        writer.write { nil }
        let answered = await writer.flushed()
        XCTAssertFalse(answered, "인코딩을 못 했으면 디스크에 없다 — 호출부가 사본을 지우면 안 된다")
        writer.write { nil }
        XCTAssertFalse(writer.flush())
    }

    /// 방금 넣은 기록이 디스크에 닿은 뒤에만 true — 그 전엔 답하지 않고, 기다리는 동안 메인을 막지 않는다.
    @MainActor
    func testFlushAfterLoadAnswersAfterMomentLandsWithoutBlockingMain() async throws {
        let url = tempURL("days-async")
        let store = DayStore(fileURL: url, closures: DayClosures(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        func onDisk() -> Int {
            ((try? JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [Any])?.count ?? 0
        }
        let gate = DispatchSemaphore(value: 0)
        let blocking = DispatchSemaphore(value: 0)
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { gate.signal() }
        CoalescingWriter.forFile(url).then { blocking.signal(); gate.wait() }
        // then 은 막기 전에 밀린 쓰기부터 비운다 — 큐가 막힌 걸 본 뒤에 넣어야 기록이 gate 뒤에 쓰인다.
        XCTAssertEqual(blocking.wait(timeout: .now() + 2), .success)
        store.add(Moment(capturedAt: Date(), colorHex: "#112233", fileName: "a.jpg", source: .app))
        let answered = LockedBox(false)
        let flushing = Task { @MainActor () -> Bool in
            let ok = await store.flushAfterLoad()
            answered.set(true)
            return ok
        }
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertFalse(answered.get(), "기록이 디스크에 닿기 전에 답이 왔거나 메인이 막혔다")
        XCTAssertEqual(onDisk(), 0)
        gate.signal()
        let written = await flushing.value
        XCTAssertTrue(written)
        XCTAssertEqual(onDisk(), 1)
    }

    func testDefaultExpiringActivityReleases() {
        let release = CoalescingWriter.expiringActivity("test")
        release()
        release()
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
