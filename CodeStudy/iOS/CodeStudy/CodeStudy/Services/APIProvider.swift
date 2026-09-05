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
                } catch let urlError as URLError {
                    if urlError.code == .cancelled {
                        // Task 취소가 URLError로 올라오는 경로 — 오류가 아니다.
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: Self.mapURLError(urlError))
                    }
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
        // 서버 로깅용 익명 식별자. 서버는 이 값으로 DAU/세션을 집계한다.
        request.setValue(AnonymousID.current, forHTTPHeaderField: "X-CodeStudy-UserID")
        request.setValue(context.sessionId, forHTTPHeaderField: "X-CodeStudy-SessionID")

        var allMessages = context.previousMessages
        var userMessage = message
        if let hint = context.actionHint {
            userMessage = "[\(hint.rawValue)] \(message)"
        }
        allMessages.append(MessageSnapshot(role: "user", content: userMessage))

        let body = TutorRequest(
            messages: allMessages,
            conceptId: context.conceptID,
            sessionId: context.sessionId,
            userProfile: .init(
                level: context.userProfile.swiftLevel,
                language: context.userProfile.preferredLanguage
            ),
            track: context.userProfile.track
        )

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    /// URLError를 사용자에게 보여줄 AIServiceError로 옮긴다.
    ///
    /// 이걸 안 하면 모든 네트워크 오류가 `.streamingFailed`("응답을 받는 중
    /// 오류가 발생했습니다")로 뭉개져서, 기기 인터넷이 끊긴 건지 SSE 연결만
    /// 잘린 건지 사용자도 로그도 구분하지 못한다.
    static func mapURLError(_ error: URLError) -> AIServiceError {
        switch error.code {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            // 기기가 실제로 오프라인 — "인터넷 연결을 확인해주세요"가 맞는 안내.
            return .networkUnavailable
        case .networkConnectionLost, .timedOut, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .secureConnectionFailed,
             .resourceUnavailable:
            // 인터넷은 살아있는데 이 연결만 끊긴 경우. 재시도로 대개 복구된다.
            return .connectionInterrupted
        default:
            return .streamingFailed
        }
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
