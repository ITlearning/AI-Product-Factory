import UIKit

/// 홈 화면 아이콘을 고른 조약돌 모양에 맞춘다. 둥근 돌 = 기본 아이콘, 반듯한 돌 = AppIcon-Classic.
/// 바꿀 때마다 iOS 가 「아이콘을 변경했습니다」 알림을 띄운다(숨길 수 없다) — 설정에서 고를 때와 온보딩을 마칠 때만 부른다.
@MainActor
enum AppIconStyle {
    static func iconName(for style: PebbleStyle) -> String? {
        switch style {
        case .round: nil
        case .classic: "AppIcon-Classic"
        }
    }

    static func apply(_ style: PebbleStyle) {
        let app = UIApplication.shared
        let target = iconName(for: style)
        guard app.supportsAlternateIcons, app.alternateIconName != target else { return }
        app.setAlternateIconName(target) { _ in }
    }
}
