import Foundation
@testable import CodeStudy

final class MockAIService: AIService, @unchecked Sendable {

    var responses: [String] = ["Hello, ", "let's learn!"]
    var shouldError: AIServiceError?

    /// Tracks calls for assertion
    private(set) var sentMessages: [(message: String, context: ConversationContext)] = []

    func sendMessage(
        _ message: String,
        context: ConversationContext
    ) -> AsyncThrowingStream<String, Error> {
        sentMessages.append((message: message, context: context))

        return AsyncThrowingStream { continuation in
            if let error = self.shouldError {
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
