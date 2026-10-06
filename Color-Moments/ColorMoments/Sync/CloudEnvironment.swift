import Foundation

/// 이 빌드가 붙는 CloudKit 환경. Xcode 직접 설치는 Development, TestFlight·App Store 는 Production 이다.
enum CloudEnvironment: String {
    case development, production

    // Ad Hoc 배포도 embedded.mobileprovision 이 붙지만 Production 이다 — 이 앱은 Ad Hoc 으로 배포하지 않는다.
    static func detect(hasProvisioningProfile: Bool, isSimulator: Bool) -> CloudEnvironment {
        hasProvisioningProfile || isSimulator ? .development : .production
    }

    static var current: CloudEnvironment {
        #if targetEnvironment(simulator)
        let simulator = true
        #else
        let simulator = false
        #endif
        let profile = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") != nil
        return detect(hasProvisioningProfile: profile, isSimulator: simulator)
    }

    enum Decision: Equatable {
        case keep, record, reset
    }

    /// 다른 환경에서 받은 동기화 상태로 시작하면 이 환경에 아무것도 다시 올리지 않는다 — 그런 상태는 버린다.
    /// 환경을 적기 전 설치는 상태가 어느 환경 것인지 모르니 한 번 버리고 전부 다시 올린다.
    static func decide(saved: CloudEnvironment?, current: CloudEnvironment, hasState: Bool) -> Decision {
        switch saved {
        case current: .keep
        case nil: hasState ? .reset : .record
        default: .reset
        }
    }
}
