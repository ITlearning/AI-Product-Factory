import Foundation

enum ReviewPrompt {
    static let askedVersionKey = "reviewPromptAskedVersion"

    /// 다른 날 돌아와 홈에서 두 번째 조약돌을 받은 사람에게만, 버전마다 한 번.
    static func shouldAsk(giftedDays: Int, askedVersion: String?, currentVersion: String) -> Bool {
        giftedDays >= 2 && askedVersion != currentVersion
    }

    static func claim(giftedDays: Int, defaults: UserDefaults = .standard,
                      currentVersion: String = Bundle.main.shortVersion) -> Bool {
        guard shouldAsk(giftedDays: giftedDays, askedVersion: defaults.string(forKey: askedVersionKey),
                        currentVersion: currentVersion) else { return false }
        defaults.set(currentVersion, forKey: askedVersionKey)
        return true
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }
}
