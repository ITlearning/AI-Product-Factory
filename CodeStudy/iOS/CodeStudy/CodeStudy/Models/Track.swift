import Foundation

/// 학습 트랙. 동일 앱 안에서 여러 도메인(언어/플랫폼)을 다루기 위한 추상화.
///
/// 검증 파이프라인:
/// 1. Tabber가 CLI 스킬로 만들어 target community에 배포
/// 2. 만족 시그널 확인되면 → 모바일 앱 트랙으로 port
/// 3. 각 트랙 = `curriculum_{rawValue}_{ko|en}.json` 50 concepts
///
/// 새 트랙 추가는 enum case + curriculum JSON 2개 + 약간의 UI 라벨이면 끝.
enum TrackType: String, Codable, CaseIterable, Identifiable {
    case swift
    case backend

    var id: String { rawValue }

    /// 사용자 언어에 맞는 라벨. UserProfile.language 기반으로 호출.
    func displayName(for language: AppLanguage) -> String {
        language == .korean ? displayName_ko : displayName_en
    }

    var displayName_ko: String {
        switch self {
        case .swift: return "Swift / iOS"
        case .backend: return "Backend / Spring"
        }
    }

    var displayName_en: String {
        switch self {
        case .swift: return "Swift / iOS"
        case .backend: return "Backend / Spring"
        }
    }

    /// Track 카드 설명 (Onboarding TrackStepView 사용).
    func tagline(for language: AppLanguage) -> String {
        language == .korean ? tagline_ko : tagline_en
    }

    var tagline_ko: String {
        switch self {
        case .swift: return "Swift로 iOS 앱 만들기"
        case .backend: return "Kotlin과 Spring으로 서버 만들기"
        }
    }

    var tagline_en: String {
        switch self {
        case .swift: return "Build iOS apps with Swift"
        case .backend: return "Build servers with Kotlin and Spring"
        }
    }

    /// SF Symbol — 트랙 카드/Settings에 시각 표시.
    var icon: String {
        switch self {
        case .swift: return "swift"
        case .backend: return "server.rack"
        }
    }
}
