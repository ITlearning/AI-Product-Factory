import Foundation

// MARK: - Protocol

protocol AIService: Sendable {
    func sendMessage(
        _ message: String,
        context: ConversationContext
    ) -> AsyncThrowingStream<String, Error>
}

// MARK: - Context Types

struct ConversationContext: Sendable {
    let conceptID: String
    let conceptTitle: String
    /// 한 StudySession 동안 고정되는 ID. 서버 로깅에서 동일 세션 내 turn들을
    /// 묶기 위해 사용. 기존에는 APIProvider가 매 요청마다 새 UUID를 발급해서
    /// 턴들이 같은 세션으로 묶이지 않는 버그가 있었음.
    let sessionId: String
    let userProfile: UserProfileSnapshot
    let previousMessages: [MessageSnapshot]
    let actionHint: ActionHint?
}

struct UserProfileSnapshot: Sendable {
    let hasDevelopmentExperience: Bool
    let swiftLevel: String  // "beginner"/"basic"/"intermediate"/"advanced"
    let preferredLanguage: String  // "ko"/"en"
}

struct MessageSnapshot: Sendable, Codable {
    let role: String  // "user"/"assistant"
    let content: String
}

enum ActionHint: String, Sendable {
    case simpler
    case hint
    case quiz
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case networkUnavailable
    case serverError(statusCode: Int)
    case rateLimited
    case dailyLimitExceeded
    case sessionTurnLimitExceeded
    case streamingFailed
    case invalidResponse
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return String(localized: "인터넷 연결을 확인해주세요")
        case .serverError(let code):
            return "서버 오류가 발생했습니다 (\(code))"
        case .rateLimited:
            return String(localized: "잠시 후 다시 시도해주세요")
        case .dailyLimitExceeded:
            return String(localized: "오늘 학습을 모두 완료했어요!")
        case .sessionTurnLimitExceeded:
            return String(localized: "이 세션의 대화 한도에 도달했어요")
        case .streamingFailed:
            return String(localized: "응답을 받는 중 오류가 발생했습니다")
        case .invalidResponse:
            return String(localized: "잘못된 응답입니다")
        case .saveFailed:
            return String(localized: "학습 데이터 저장에 실패했습니다")
        }
    }
}

// MARK: - API Request/Response

struct TutorRequest: Encodable {
    let messages: [MessageSnapshot]
    let conceptId: String
    let sessionId: String
    let userProfile: TutorUserProfile

    struct TutorUserProfile: Encodable {
        let level: String
        let language: String
    }
}
