import Foundation
import OSLog

/// 설정을 열 때 App Store 에 이 앱의 최신 버전을 묻는다 — 스토어가 더 높을 때만 「새 버전이 있어요」.
/// 하루 한 번만 묻고, 실패·아직 출시 전(결과 0건)이면 없는 것으로 친다. 앱 본체 전용 — 확장에선 부르지 않는다.
struct UpdateCheck {
    static let lookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=com.itlearning.colormoments&country=kr")!
    static let storeURL = URL(string: "itms-apps://apps.apple.com/app/id6817888379")!
    static let interval: TimeInterval = 24 * 3600

    static let checkedAtKey = "storeVersionCheckedAt"
    static let versionKey = "storeVersion"

    private static let log = Logger(subsystem: "com.itlearning.colormoments", category: "update")

    var fetch: (URL) async throws -> Data
    var defaults: UserDefaults = .standard
    var now: () -> Date = Date.init

    // ephemeral — 쿠키·캐시를 남기지 않는다. 주소의 bundleId·country 말고는 보내는 값이 없다.
    private static let session = URLSession(configuration: .ephemeral)

    static let live = UpdateCheck { url in
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        let (data, response) = try await UpdateCheck.session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    /// 스토어 버전이 current 보다 높으면 그 버전, 아니면 nil.
    func newerVersion(than current: String) async -> String? {
        guard let store = await storeVersion(), Self.isNewer(store, than: current) else { return nil }
        return store
    }

    /// 하루 안에 받은 답이 있으면 그것을 쓴다. 실패는 담아 두지 않아 다음에 열 때 다시 묻는다.
    func storeVersion() async -> String? {
        if let checked = defaults.object(forKey: Self.checkedAtKey) as? Date,
           checked <= now(), now().timeIntervalSince(checked) < Self.interval {
            return defaults.string(forKey: Self.versionKey)
        }
        do {
            let version = try JSONDecoder().decode(Lookup.self, from: try await fetch(Self.lookupURL)).results.first?.version
            defaults.set(now(), forKey: Self.checkedAtKey)
            defaults.set(version, forKey: Self.versionKey)
            return version
        } catch {
            Self.log.notice("스토어 버전 조회 실패 — \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// 점으로 나눈 숫자끼리 — 1.10 > 1.9, 1.0 == 1.0.0. 숫자가 아닌 칸이 있으면 높지 않은 것으로 친다.
    static func isNewer(_ a: String, than b: String) -> Bool {
        guard let x = numbers(a), let y = numbers(b) else { return false }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private static func numbers(_ version: String) -> [Int]? {
        let parts = version.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, !parts.contains(nil) else { return nil }
        return parts.compactMap { $0 }
    }

    private struct Lookup: Decodable {
        struct Result: Decodable { let version: String }
        let results: [Result]
    }
}

/// 번들 값 그대로 — 설정 맨 아래 「버전 1.0.0 (2)」.
struct AppVersion: Equatable {
    let short: String
    let build: String

    static let current = AppVersion(info: Bundle.main.infoDictionary ?? [:])

    init(info: [String: Any]) {
        short = info["CFBundleShortVersionString"] as? String ?? "?"
        build = info["CFBundleVersion"] as? String ?? "?"
    }

    var line: String { "버전 \(short) (\(build))" }
}
