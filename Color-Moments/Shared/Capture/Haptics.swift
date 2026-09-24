import UIKit

enum Haptics {
    private static let tick = UIImpactFeedbackGenerator(style: .light)
    private static let snap = UIImpactFeedbackGenerator(style: .medium)
    private static let shutter = UIImpactFeedbackGenerator(style: .soft)

    static func prepare() {
        tick.prepare(); snap.prepare(); shutter.prepare()
    }

    static func tickPassed() { tick.impactOccurred(intensity: 0.55) }

    static func snapped() { snap.impactOccurred() }

    static func captured() { shutter.impactOccurred(intensity: 0.8) }
}
