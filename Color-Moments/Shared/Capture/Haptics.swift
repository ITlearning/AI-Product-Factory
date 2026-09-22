import UIKit

/// 줌 다이얼의 촉감.
///
/// 눈금을 지날 때 톡톡, 프리셋에 붙을 때 한 번 더 확실하게. 기본 카메라와 같은 감각이다.
/// 생성기를 매번 만들면 첫 진동이 늦게 온다 — 미리 준비해 두고 재사용한다.
enum Haptics {
    private static let tick = UIImpactFeedbackGenerator(style: .light)
    private static let snap = UIImpactFeedbackGenerator(style: .medium)
    private static let shutter = UIImpactFeedbackGenerator(style: .soft)

    static func prepare() {
        tick.prepare(); snap.prepare(); shutter.prepare()
    }
    /// 눈금 하나를 지날 때.
    static func tickPassed() { tick.impactOccurred(intensity: 0.55) }
    /// 프리셋 배율에 붙을 때.
    static func snapped() { snap.impactOccurred() }
    /// 셔터.
    static func captured() { shutter.impactOccurred(intensity: 0.8) }
}
