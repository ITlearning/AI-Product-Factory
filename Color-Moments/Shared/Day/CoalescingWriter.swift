import Foundation

/// 파일 하나에 대한 쓰기를 백그라운드 직렬 큐에서 — 밀린 요청은 마지막 것만 인코딩·쓴다.
/// 같은 파일은 같은 인스턴스를 쓴다(새로 연 저장소가 flush 뒤 읽어야 앞 저장소의 마지막 쓰기를 본다).
public final class CoalescingWriter: @unchecked Sendable {

    private static let registryLock = NSLock()
    private static var registry: [URL: CoalescingWriter] = [:]

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

    private init(url: URL) {
        self.url = url
        self.queue = DispatchQueue(label: "mongdol.write.\(url.lastPathComponent)", qos: .utility)
    }

    /// make 는 백그라운드에서 돈다 — 값 스냅샷만 잡아야 한다(저장소 객체를 잡으면 경쟁).
    public func write(_ make: @escaping @Sendable () -> Data?) {
        lock.lock()
        let idle = pending == nil
        pending = make
        lock.unlock()
        if idle { queue.async { self.drain() } }
    }

    /// 밀린 쓰기까지 끝날 때까지 기다린다 — 앱이 background 로 갈 때·같은 파일을 다시 읽기 전에.
    public func flush() {
        queue.sync { drain() }
    }

    private func drain() {
        lock.lock()
        let make = pending
        pending = nil
        lock.unlock()
        guard let make, let data = make() else { return }
        try? data.write(to: url, options: .atomic)
    }
}
