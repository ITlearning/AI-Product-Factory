import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var hasDevelopmentExperience: Bool
    var swiftLevel: String  // SwiftLevel rawValue
    var preferredLanguage: String  // AppLanguage rawValue
    var dailySessionCount: Int
    var lastSessionCountResetDate: Date

    init(
        hasDevelopmentExperience: Bool = false,
        swiftLevel: SwiftLevel = .beginner,
        preferredLanguage: AppLanguage = .korean
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.hasDevelopmentExperience = hasDevelopmentExperience
        self.swiftLevel = swiftLevel.rawValue
        self.preferredLanguage = preferredLanguage.rawValue
        self.dailySessionCount = 0
        self.lastSessionCountResetDate = Date()
    }

    var level: SwiftLevel {
        get { SwiftLevel(rawValue: swiftLevel) ?? .beginner }
        set { swiftLevel = newValue.rawValue }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: preferredLanguage) ?? .korean }
        set { preferredLanguage = newValue.rawValue }
    }
}

enum SwiftLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case basic
    case intermediate
    case advanced

    var id: String { rawValue }

    var displayName_ko: String {
        switch self {
        case .beginner: return "처음"
        case .basic: return "기초"
        case .intermediate: return "중급"
        case .advanced: return "고급"
        }
    }

    var displayName_en: String {
        switch self {
        case .beginner: return "Beginner"
        case .basic: return "Basic"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

enum AppLanguage: String, Codable {
    case korean = "ko"
    case english = "en"
}
