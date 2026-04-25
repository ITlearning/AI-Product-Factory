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
        preferredLanguage: AppLanguage = .systemDefault
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

    /// 사용자 설정 언어 기반 라벨. View/ViewModel에서 직접 분기 안 하도록 헬퍼 제공.
    func displayName(for language: AppLanguage) -> String {
        language == .korean ? displayName_ko : displayName_en
    }
}

enum AppLanguage: String, Codable {
    case korean = "ko"
    case english = "en"

    /// 디바이스 locale 기반 기본 언어.
    /// - 한국어 디바이스 → `.korean`
    /// - 그 외 모든 언어 → `.english` (영어권 진출 정책: 영어를 글로벌 기본으로)
    ///
    /// 신규 `UserProfile` 생성 시 기본값으로 사용. 기존 사용자는 영향 없음.
    /// 사용자는 Settings 탭에서 언제든지 직접 변경 가능.
    static var systemDefault: AppLanguage {
        let code = Locale.current.language.languageCode?.identifier
        return code == "ko" ? .korean : .english
    }
}
