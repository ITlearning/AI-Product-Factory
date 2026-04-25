import Foundation
import Observation

/// 서버에서 받은 런타임 설정.
///
/// - 설문 URL은 앱 심사를 거치지 않고 변경 가능해야 한다 (Cycle 2 요구사항).
/// - 응답이 충분히 모이면 `surveyEnabled=false`로 즉시 끌 수 있어야 한다.
///
/// 디스크 캐시(UserDefaults) + 메모리 캐시 + 백그라운드 새로고침으로
/// 네트워크가 죽어도 마지막 알려진 설정으로 계속 동작한다.
@Observable
final class ConfigService {
    // MARK: - Public state

    /// 마지막으로 알려진 설정. 캐시가 없으면 안전한 기본값.
    private(set) var current: AppRemoteConfig = .disabledFallback

    /// 마지막 성공적인 fetch 시각 (TTL 판단용).
    private(set) var lastFetchedAt: Date?

    // MARK: - Dependencies

    private let baseURL: URL
    private let session: URLSession
    private let userDefaults: UserDefaults
    private let cacheKey = "codestudy.remoteConfig.v1"
    private let timestampKey = "codestudy.remoteConfig.fetchedAt.v1"

    /// 백그라운드에서 한 번 더 호출하지 않을 캐시 유효 시간.
    private let staleAfter: TimeInterval = 30 * 60 // 30분

    // MARK: - Init

    init(
        baseURL: URL,
        session: URLSession = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.baseURL = baseURL
        self.session = session
        self.userDefaults = userDefaults
        loadFromDisk()
    }

    // MARK: - Public API

    /// 캐시가 stale일 때만 서버 fetch.
    /// 앱 시작, foreground 진입, SurveyModalView 노출 직전 호출.
    func refreshIfStale() async {
        if let last = lastFetchedAt, Date().timeIntervalSince(last) < staleAfter {
            return
        }
        await refresh()
    }

    /// 강제 fetch. 결과는 캐시에 저장. 실패하면 기존 값 유지.
    @discardableResult
    func refresh() async -> Bool {
        let endpoint = baseURL.appendingPathComponent("api/config")
        var request = URLRequest(url: endpoint, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            let decoded = try JSONDecoder().decode(AppRemoteConfig.self, from: data)
            await MainActor.run {
                self.current = decoded
                self.lastFetchedAt = Date()
                self.persist(decoded)
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        if let data = userDefaults.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode(AppRemoteConfig.self, from: data) {
            self.current = decoded
        }
        if let ts = userDefaults.object(forKey: timestampKey) as? Date {
            self.lastFetchedAt = ts
        }
    }

    private func persist(_ config: AppRemoteConfig) {
        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: cacheKey)
        }
        userDefaults.set(Date(), forKey: timestampKey)
    }
}

// MARK: - Model

struct AppRemoteConfig: Codable, Equatable {
    let schemaVersion: Int
    let surveyEnabled: Bool
    let surveyURLString: String
    /// 영문 form URL. 비어있으면 한글 URL로 fallback (schema v1 호환).
    let surveyURLEnString: String

    /// 한글 검증된 URL. 잘못된 문자열이면 nil.
    var surveyURL: URL? {
        guard !surveyURLString.isEmpty else { return nil }
        return URL(string: surveyURLString)
    }

    /// 영문 검증된 URL. 비어있거나 잘못된 문자열이면 nil.
    var surveyURLEn: URL? {
        guard !surveyURLEnString.isEmpty else { return nil }
        return URL(string: surveyURLEnString)
    }

    /// 사용자 언어에 맞는 form URL.
    /// - 영어: 영문 URL 우선 → 없으면 한글 URL fallback (영문 form 미준비 시)
    /// - 그 외: 한글 URL → 없으면 영문 URL (영어권 단독 출시 시나리오)
    func surveyURL(for language: AppLanguage) -> URL? {
        switch language {
        case .english:
            return surveyURLEn ?? surveyURL
        case .korean:
            return surveyURL ?? surveyURLEn
        }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case surveyEnabled
        case surveyURLString = "surveyURL"
        case surveyURLEnString = "surveyURLEn"
    }

    /// schema v1 호환 디코딩: 옛 응답엔 surveyURLEn 필드가 없을 수 있음.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.surveyEnabled = try container.decode(Bool.self, forKey: .surveyEnabled)
        self.surveyURLString = try container.decodeIfPresent(String.self, forKey: .surveyURLString) ?? ""
        self.surveyURLEnString = try container.decodeIfPresent(String.self, forKey: .surveyURLEnString) ?? ""
    }

    /// memberwise init (정상 path + fallback 생성).
    init(schemaVersion: Int, surveyEnabled: Bool, surveyURLString: String, surveyURLEnString: String) {
        self.schemaVersion = schemaVersion
        self.surveyEnabled = surveyEnabled
        self.surveyURLString = surveyURLString
        self.surveyURLEnString = surveyURLEnString
    }

    /// 첫 실행, 서버 미도달, 디코딩 실패 시 기본값.
    /// 설문 자체가 꺼진 상태로 시작 → 잘못된 URL 노출 위험 0.
    static let disabledFallback = AppRemoteConfig(
        schemaVersion: 2,
        surveyEnabled: false,
        surveyURLString: "",
        surveyURLEnString: ""
    )
}
