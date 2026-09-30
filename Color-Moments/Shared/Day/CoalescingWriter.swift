import Foundation

/// 파일 하나에 대한 쓰기를 백그라운드 직렬 큐에서 — 밀린 요청은 마지막 것만 인코딩·쓴다.
/// 같은 파일은 같은 인스턴스를 쓴다(새로 연 저장소가 flush 뒤 읽어야 앞 저장소의 마지막 쓰기를 본다).
public final class CoalescingWriter: @unchecked Sendable {

    public typealias Release = @Sendable () -> Void

    private static let registryLock = NSLock()
    private static var registry: [URL: CoalescingWriter] = [:]
    private static var holder: @Sendable (String) -> Release = expiringActivity

    /// 밀린 쓰기 동안 프로세스를 붙잡는 방법 — 확장에서도 되는 기본값, 앱은 beginBackgroundTask 로 바꿔 꽂는다.
    public static var activityHolder: @Sendable (String) -> Release {
        get { registryLock.lock(); defer { registryLock.unlock() }; return holder }
        set { registryLock.lock(); holder = newValue; registryLock.unlock() }
    }

    /// performExpiringActivity 는 블록이 도는 동안만 붙잡는다 — 놓을 때까지 블록을 세워 둔다.
    /// 붙잡는 블록은 부른 쪽 QoS 를 물려받는다 — 메인에서 부르면 높은 QoS 스레드가 utility 쓰기 큐를 기다리는
    /// 우선순위 역전(Thread Performance Checker)이 된다. 쓰기 큐와 같은 utility 에서 시작한다.
    public static func expiringActivity(_ reason: String) -> Release {
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { expired in
                if expired { done.signal(); return }
                done.wait()
            }
        }
        return { done.signal() }
    }

    public static func forFile(_ url: URL) -> CoalescingWriter {
        registryLock.lock()
        defer { registryLock.unlock() }
        if let w = registry[url] { return w }
        let w = CoalescingWriter(url: url)
        registry[url] = w
        return w
    }

    private let url: URL
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var pending: (@Sendable () -> Data?)?
    /// 마지막 쓰기가 끝내 실패했는지 — 큐 위에서만 읽고 쓴다.
    private var lastWriteFailed = false

    private init(url: URL) {
        self.url = url
        self.queue = DispatchQueue(label: "mongdol.write.\(url.lastPathComponent)", qos: .utility)
    }

    private func hold() -> Release {
        Self.activityHolder("mongdol.write.\(url.lastPathComponent)")
    }

    /// make 는 백그라운드에서 돈다 — 값 스냅샷만 잡아야 한다(저장소 객체를 잡으면 경쟁).
    public func write(_ make: @escaping @Sendable () -> Data?) {
        lock.lock()
        let idle = pending == nil
        pending = make
        lock.unlock()
        guard idle else { return }
        let release = hold()
        queue.async {
            self.drain()
            release()
        }
    }

    /// 밀린 쓰기까지 끝날 때까지 기다린다 — 앱이 background 로 갈 때·같은 파일을 다시 읽기 전에.
    /// false 면 마지막 쓰기가 디스크에 닿지 못했다 — 되돌릴 수 없는 일(파일 삭제 등)은 하지 않는다.
    @discardableResult
    public func flush() -> Bool {
        queue.sync {
            drain()
            return !lastWriteFailed
        }
    }

    public func flushed() async -> Bool {
        await withCheckedContinuation { done in
            queue.async {
                self.drain()
                done.resume(returning: !self.lastWriteFailed)
            }
        }
    }

    /// 밀린 쓰기가 디스크에 닿은 뒤 같은 큐에서 work 를 돌린다 — 다른 파일이 이 파일보다 먼저 남으면 안 될 때.
    public func then(_ work: @escaping @Sendable () -> Void) {
        let release = hold()
        queue.async {
            self.drain()
            work()
            release()
        }
    }

    private func drain() {
        lock.lock()
        let make = pending
        pending = nil
        lock.unlock()
        guard let make else { return }
        guard let data = make() else {
            lastWriteFailed = true
            print("CoalescingWriter: \(url.lastPathComponent) 인코딩 실패")
            return
        }
        do {
            try data.write(to: url, options: .atomic)
            lastWriteFailed = false
        } catch {
            lastWriteFailed = (try? data.write(to: url, options: .atomic)) == nil
            if lastWriteFailed { print("CoalescingWriter: \(url.lastPathComponent) 쓰기 실패 \(error)") }
        }
    }
}
