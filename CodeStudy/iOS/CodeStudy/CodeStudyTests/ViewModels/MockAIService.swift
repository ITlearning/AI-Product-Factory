import Foundation
@testable import CodeStudy

final class MockAIService: AIService, @unchecked Sendable {

    var responses: [String] = ["Hello, ", "let's learn!"]
    var shouldError: AIServiceError?

    /// 오류/취소로 끊기기 직전까지 흘려보낼 부분 chunk들.
    /// 응답이 절반쯤 오다가 연결이 잘리는 상황을 재현한다.
    var chunksBeforeInterruption: [String] = []

    /// APIProvider가 취소를 CancellationError로 올려보내는 상황을 재현한다.
    /// `shouldError`보다 우선한다.
    var shouldCancel = false

    /// Tracks calls for assertion
    private(set) var sentMessages: [(message: String, context: ConversationContext)] = []

    func sendMessage(
        _ message: String,
        context: ConversationContext
    ) -> AsyncThrowingStream<String, Error> {
        sentMessages.append((message: message, context: context))

        return AsyncThrowingStream { continuation in
            if self.shouldCancel {
                for chunk in self.chunksBeforeInterruption {
                    continuation.yield(chunk)
                }
                continuation.finish(throwing: CancellationError())
                return
            }
            if let error = self.shouldError {
                for chunk in self.chunksBeforeInterruption {
                    continuation.yield(chunk)
                }
                continuation.finish(throwing: error)
                return
            }
            for chunk in self.responses {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}
