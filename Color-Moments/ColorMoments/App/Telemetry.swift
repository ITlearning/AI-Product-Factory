import Foundation
import Photos
import TelemetryDeck

/// 익명 사용 기록(TelemetryDeck) — 보내는 이름과 값은 이 파일에 적힌 것뿐이다.
/// 사진·단어·색·조약돌 이름·위치·날짜 키·파일명은 보내지 않는다. 앱 본체만 — 확장엔 없다.
enum Telemetry {

    /// TelemetryDeck 앱 ID — 비어 있으면 SDK 를 켜지도, 아무것도 보내지도 않는다.
    static let appID = ""

    static let enabledKey = "sendsTelemetry"
    static let firstPhotoKey = "telemetryFirstPhoto"
    static let firstPebbleKey = "telemetryFirstPebble"

    enum Source: String, CaseIterable { case app, locked, library }
    enum Answer: String, CaseIterable { case allowed, limited, denied, declined }
    enum Exit: String, CaseIterable { case home, camera, day }
    enum Place: String, CaseIterable { case onboarding, home }
    enum CameraPath: String, CaseIterable { case swipe, button, control }

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
        case wordRejected

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
            case .wordRejected: [:]
            }
        }

        var floatValue: Double? {
            if case .photoAdded(_, let count) = self { return Double(count) }
            return nil
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

    static func sends(appID: String, enabled: Bool, testing: Bool) -> Bool {
        !appID.isEmpty && enabled && !testing
    }

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    private static let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private static var sending: Bool { sends(appID: appID, enabled: isEnabled, testing: isTesting) }

    private enum State { case idle, on, off }
    private static var state = State.idle

    /// 앱 시작과 설정 스위치에서 — 껐으면 SDK 를 「분석 꺼짐」으로 다시 세운다(세션 신호까지 막힌다).
    static func apply() {
        if sending {
            guard state != .on else { return }
            TelemetryDeck.initialize(config: .init(appID: appID))
            state = .on
        } else if state == .on {
            // terminate() 는 쓰지 않는다 — 뒤에 남은 세션 관찰자가 빈 매니저를 부르면 디버그에서 멈춘다.
            var config = TelemetryDeck.Config(appID: appID)
            config.analyticsDisabled = true
            config.sessionStatsEnabled = false
            TelemetryDeck.initialize(config: config)
            state = .off
        }
    }

    static func send(_ event: Event) {
        guard state == .on, sending else { return }
        TelemetryDeck.signal(event.name, parameters: event.parameters, floatValue: event.floatValue)
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
