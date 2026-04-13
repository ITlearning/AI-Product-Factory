import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // Dynamic colors that adapt to light/dark mode
    static let deepBlue = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.65, blue: 0.95, alpha: 1.0)   // lighter blue for dark bg
            : UIColor(red: 0.118, green: 0.227, blue: 0.373, alpha: 1.0) // #1E3A5F
    })

    static let warmOrange = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)     // slightly brighter for dark bg
            : UIColor(red: 1.0, green: 0.420, blue: 0.208, alpha: 1.0)  // #FF6B35
    })

    // For user message bubbles — keep deep blue even in dark mode (it's on a colored bg, not the app bg)
    static let userBubbleColor = Color(hex: "1E3A5F")  // static, doesn't change

    // For concept cards, onboarding cards — need subtle background that works in both modes
    static let cardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.secondarySystemBackground
            : UIColor.secondarySystemBackground
    })
}
