import Foundation

// MARK: - APIProvider

final class APIProvider: AIService, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let bundleID: String

    init(
        baseURL: URL,
        session: URLSession = .shared,
        bundleID: String = Bundle.main.bundleIdentifier ?? "com.itlearning.codestudy"
    ) {
        self.baseURL = baseURL
        self.session = session
        self.bundleID = bundleID
    }

    func sendMessage(
        _ message: String,
        context: ConversationContext
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try buildRequest(message: message, context: context)
                    let (bytes, response) = try await session.bytes(for: request)

                    try mapHTTPResponse(response)

                    for try await line in bytes.lines {
                        try Task.checkCancellation()

                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))

                        if payload == "[DONE]" {
                            break
                        }

                        guard let data = payload.data(using: .utf8) else { continue }

                        if let chunk = try? JSONDecoder().decode(TextChunk.self, from: data) {
                            continuation.yield(chunk.t)
                        } else if let done = try? JSONDecoder().decode(DoneChunk.self, from: data) {
                            if done.done {
                                // Signal mastery by appending the [MASTERY] marker.
                                // ChatViewModel strips this from displayed content
                                // and uses it to trigger the completion sheet.
                                if done.mastered == true {
                                    continuation.yield("[MASTERY]")
                                }
                                break
                            }
                        }
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private

    private func buildRequest(
        message: String,
        context: ConversationContext
    ) throws -> URLRequest {
        let endpoint = baseURL.appendingPathComponent("api/tutor")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(bundleID, forHTTPHeaderField: "X-App-Bundle-Id")

        var allMessages = context.previousMessages
        var userMessage = message
        if let hint = context.actionHint {
            userMessage = "[\(hint.rawValue)] \(message)"
        }
        allMessages.append(MessageSnapshot(role: "user", content: userMessage))

        let body = TutorRequest(
            messages: allMessages,
            conceptId: context.conceptID,
            sessionId: UUID().uuidString,
            userProfile: .init(
                level: context.userProfile.swiftLevel,
                language: context.userProfile.preferredLanguage
            )
        )

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func mapHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 429:
            throw AIServiceError.rateLimited
        case 500...599:
            throw AIServiceError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw AIServiceError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - SSE Chunk Types

private struct TextChunk: Decodable {
    let t: String
}

private struct DoneChunk: Decodable {
    let done: Bool
    let mastered: Bool?
}
