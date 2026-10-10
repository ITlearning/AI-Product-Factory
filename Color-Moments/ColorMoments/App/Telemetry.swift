import Foundation
import Photos
import PostHog

/// 익명 사용 기록(PostHog) — 보내는 이름과 값은 이 파일에 적힌 것뿐이다.
/// 사진·단어·색·조약돌 이름·위치·날짜 키·파일명은 보내지 않는다. 앱 본체만 — 확장엔 없다.
enum Telemetry {

    /// PostHog Project API Key(`phc_…`) — 비어 있으면 SDK 를 켜지도, 아무것도 보내지도 않는다.
    static let apiKey = "phc_nQAKwQjfrQnNCXC4FomYsLBH79wA4jVnokYKw7uMLicK"
    static let host = "https://eu.i.posthog.com"

    static let enabledKey = "sendsTelemetry"
    static let firstPhotoKey = "telemetryFirstPhoto"
    static let firstPebbleKey = "telemetryFirstPebble"

    enum Source: String, CaseIterable { case app, locked, library, today }
    enum Answer: String, CaseIterable { case allowed, limited, denied, declined }
    enum Exit: String, CaseIterable { case home, camera, day }
    enum Place: String, CaseIterable { case onboarding, home }
    enum CameraPath: String, CaseIterable { case swipe, button, control }
    enum Lag: String, CaseIterable { case same, next, later }
    enum Photos: String, CaseIterable {
        case one = "1", two = "2", threePlus = "3plus"
        init(count: Int) { self = count <= 1 ? .one : count == 2 ? .two : .threePlus }
    }
    enum Stay: String, CaseIterable {
        case short, mid, long
        init(seconds: TimeInterval) { self = seconds < 5 ? .short : seconds <= 30 ? .mid : .long }
    }
    enum Path: String, CaseIterable { case icon, notice, control, widget }

    static func lag(dayKey: String, now: Date) -> Lag {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        guard let a = f.date(from: dayKey), let b = f.date(from: Moment.dayKey(for: now)) else { return .later }
        let d = Calendar(identifier: .gregorian).dateComponents([.day], from: a, to: b).day ?? 2
        return d <= 0 ? .same : d == 1 ? .next : .later
    }

    enum Event: Equatable {
        case onboardingStep(OnboardingStep)
        case onboardingFinished(Exit)
        case photoAccess(Answer)
        case placeAccess(Answer)
        case noticeAccess(Answer)
        case firstPhoto(Source)
        case photoAdded(Source, count: Int)
        case firstPebble(Place)
        case cameraOpened(CameraPath)
        case wordRejected(String)
        case pebbleReceived(Place, lag: Lag, photos: Photos)
        case pebbleOpened
        case cameraClosed(count: Int, stay: Stay)
        case appEntered(Path)
        case todayShown
        case wordShown(String)

        var name: String {
            switch self {
            case .onboardingStep: "Onboarding.step"
            case .onboardingFinished: "Onboarding.finished"
            case .photoAccess: "Permission.photos"
            case .placeAccess: "Permission.location"
            case .noticeAccess: "Permission.notifications"
            case .firstPhoto: "First.photo"
            case .photoAdded: "Photo.added"
            case .firstPebble: "First.pebble"
            case .cameraOpened: "Camera.opened"
            case .wordRejected: "Word.rejected"
            case .pebbleReceived: "Pebble.received"
            case .pebbleOpened: "Pebble.opened"
            case .cameraClosed: "Camera.closed"
            case .appEntered: "App.entered"
            case .todayShown: "Today.shown"
            case .wordShown: "Word.shown"
            }
        }

        var parameters: [String: String] {
            switch self {
            case .onboardingStep(let s): ["step": Telemetry.stepName(s)]
            case .onboardingFinished(let e): ["exit": e.rawValue]
            case .photoAccess(let a), .placeAccess(let a), .noticeAccess(let a): ["answer": a.rawValue]
            case .firstPhoto(let s), .photoAdded(let s, _): ["source": s.rawValue]
            case .firstPebble(let p): ["where": p.rawValue]
            case .cameraOpened(let p): ["path": p.rawValue]
            case .wordRejected(let id), .wordShown(let id): ["word": id]
            case .pebbleReceived(let p, let l, let n): ["where": p.rawValue, "lag": l.rawValue, "photos": n.rawValue]
            case .cameraClosed(_, let s): ["stay": s.rawValue]
            case .appEntered(let p): ["path": p.rawValue]
            case .pebbleOpened, .todayShown: [:]
            }
        }

        var count: Int? {
            switch self {
            case .photoAdded(_, let c), .cameraClosed(let c, _): c
            default: nil
            }
        }

        var properties: [String: Any] {
            var properties: [String: Any] = parameters
            if let count { properties["count"] = count }
            return properties
        }
    }

    static let stepNames = ["intro", "firstPebble", "continuing", "place", "arrival", "reminder", "cloud",
                            "howTo", "cameraButton", "collection", "start"]

    static func stepName(_ step: OnboardingStep) -> String {
        switch step {
        case .intro: "intro"
        case .firstPebble: "firstPebble"
        case .continuing: "continuing"
        case .place: "place"
        case .arrival: "arrival"
        case .reminder: "reminder"
        case .cloud: "cloud"
        case .howTo: "howTo"
        case .cameraButton: "cameraButton"
        case .collection: "collection"
        case .start: "start"
        }
    }

    // MARK: 켜고 끄기

    static func sends(apiKey: String, enabled: Bool, testing: Bool) -> Bool {
        !apiKey.isEmpty && enabled && !testing
    }

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    private static let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private static var sending: Bool { sends(apiKey: apiKey, enabled: isEnabled, testing: isTesting) }

    /// 사진 앱이라 화면·누른 곳·위치가 나갈 길은 모두 막는다 — 우리가 부르는 capture 와 앱 열림·닫힘만 남는다.
    static func makeConfig(apiKey: String) -> PostHogConfig {
        let config = PostHogConfig(projectToken: apiKey, host: host)
        config.enableSwizzling = false
        config.sessionReplay = false
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.captureSwiftUIElementInteractions = false
        config.captureAutocaptureElementText = false
        config.rageClickConfig.enabled = false
        config.capturePushNotificationSubscriptions = false
        config.capturePushNotificationOpened = false
        config.surveys = false
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.errorTrackingConfig.autoCapture = false
        config.personProfiles = .never
        config.setDefaultPersonProperties = false
        config.disableGeoIp = true
        config.captureApplicationLifecycleEvents = true
        return config
    }

    private static var isSetUp = false

    /// 앱 시작과 설정 스위치에서 — 끈 채로 시작하면 SDK 를 아예 세우지 않는다.
    static func apply() {
        if sending {
            if !isSetUp {
                PostHogSDK.shared.setup(makeConfig(apiKey: apiKey))
                isSetUp = true
            }
            // SDK 는 optOut 을 디스크에 남겨 다음 setup 때 되살린다 — 켜져 있으면 매번 optIn 으로 풀어야 한다.
            PostHogSDK.shared.optIn()
        } else if isSetUp {
            PostHogSDK.shared.optOut()
        }
    }

    static func send(_ event: Event) {
        guard isSetUp, sending else { return }
        PostHogSDK.shared.capture(event.name, properties: event.properties)
    }

    // MARK: 정해진 지점들

    /// 「처음」 — 담기 전 기록이 비어 있던 기기에서 한 번만(업데이트한 기존 사용자·iCloud 로 이어 온 사람은 빠진다).
    static func isFirstPhoto(count: Int, total: Int, alreadyMarked: Bool) -> Bool {
        !alreadyMarked && count > 0 && total == count
    }

    static func photosAdded(_ source: Moment.Source, count: Int, total: Int, defaults: UserDefaults = .standard) {
        guard count > 0 else { return }
        let s = Source(source)
        if isFirstPhoto(count: count, total: total, alreadyMarked: defaults.bool(forKey: firstPhotoKey)) {
            defaults.set(true, forKey: firstPhotoKey)
            send(.firstPhoto(s))
        }
        send(.photoAdded(s, count: count))
    }

    /// 첫 사진을 이 기기에서 담은 사람만 — 업데이트한 기존 사용자의 조약돌은 「처음」이 아니다.
    static func isFirstPebble(startedFresh: Bool, alreadyMarked: Bool) -> Bool {
        startedFresh && !alreadyMarked
    }

    static func pebbleReceived(_ place: Place, defaults: UserDefaults = .standard) {
        guard isFirstPebble(startedFresh: defaults.bool(forKey: firstPhotoKey),
                            alreadyMarked: defaults.bool(forKey: firstPebbleKey)) else { return }
        defaults.set(true, forKey: firstPebbleKey)
        send(.firstPebble(place))
    }
}

extension Telemetry.Source {
    init(_ source: Moment.Source) {
        switch source {
        case .app: self = .app
        case .locked: self = .locked
        case .library: self = .library
        }
    }
}

extension Telemetry.Exit {
    init(_ exit: OnboardingExit) {
        switch exit {
        case .home: self = .home
        case .camera: self = .camera
        case .day: self = .day
        }
    }
}

extension Telemetry.Answer {
    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized: self = .allowed
        case .limited: self = .limited
        default: self = .denied
        }
    }
}
