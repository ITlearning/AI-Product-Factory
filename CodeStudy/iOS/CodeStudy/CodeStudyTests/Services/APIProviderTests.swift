import Testing
import Foundation
@testable import CodeStudy

@Suite("APIProvider URLError mapping")
struct APIProviderTests {

    /// 기기가 실제로 오프라인일 때만 "인터넷 연결을 확인해주세요"가 나와야 한다.
    @Test("device-offline codes map to networkUnavailable")
    func testOfflineCodes() {
        let offline: [URLError.Code] = [
            .notConnectedToInternet,
            .dataNotAllowed,
            .internationalRoamingOff,
        ]
        for code in offline {
            #expect(APIProvider.mapURLError(URLError(code)) == .networkUnavailable)
        }
    }

    /// 인터넷은 살아있는데 이 연결만 끊긴 경우. 설문 응답자가 "인터넷 문제가
    /// 없음에도 연결이 끊겼다고 오류가 뜬다"고 지적한 바로 그 상황이라,
    /// 오프라인 문구를 재사용하면 틀린 안내가 된다.
    @Test("dropped-connection codes map to connectionInterrupted")
    func testInterruptedCodes() {
        let interrupted: [URLError.Code] = [
            .networkConnectionLost,
            .timedOut,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed,
            .secureConnectionFailed,
            .resourceUnavailable,
        ]
        for code in interrupted {
            #expect(APIProvider.mapURLError(URLError(code)) == .connectionInterrupted)
        }
    }

    @Test("unrecognized codes fall back to streamingFailed")
    func testFallback() {
        #expect(APIProvider.mapURLError(URLError(.badURL)) == .streamingFailed)
    }

    @Test("offline and interrupted carry different user-facing copy")
    func testCopyDiffers() {
        let offline = AIServiceError.networkUnavailable.errorDescription
        let interrupted = AIServiceError.connectionInterrupted.errorDescription
        #expect(offline != nil)
        #expect(interrupted != nil)
        #expect(offline != interrupted)
    }

    /// 취소된 요청을 정상 종료(`finish()`)로 흘리면 ChatViewModel이 "빈 응답이
    /// 성공적으로 끝났다"고 보고 빈 말풍선을 저장한 뒤 turnCount까지 올린다.
    /// 취소는 CancellationError로 올라와야 한다.
    @Test("a request cancelled mid-flight reports cancellation, not a clean finish")
    func testCancelledRequestThrowsCancellation() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HangingURLProtocol.self]
        let session = URLSession(configuration: config)
        let provider = APIProvider(
            baseURL: URL(string: "https://codestudy.test")!,
            session: session,
            bundleID: "com.itlearning.codestudy.tests"
        )

        let consumer = Task { () -> Error? in
            do {
                for try await _ in provider.sendMessage("hi", context: Self.makeContext()) {}
                return nil
            } catch {
                return error
            }
        }

        // 요청이 응답 대기에 들어갈 시간을 준 뒤 연결을 끊는다.
        try await Task.sleep(nanoseconds: 300_000_000)
        session.invalidateAndCancel()

        let observed = await consumer.value
        guard let observed else {
            Issue.record("취소된 스트림이 오류 없이 정상 종료했다")
            return
        }
        #expect(observed is CancellationError)
    }

    // MARK: - Helpers

    private static func makeContext() -> ConversationContext {
        ConversationContext(
            conceptID: "swift-optionals",
            conceptTitle: "Optionals",
            sessionId: UUID().uuidString,
            userProfile: UserProfileSnapshot(
                hasDevelopmentExperience: false,
                swiftLevel: "beginner",
                preferredLanguage: "ko",
                track: "swift"
            ),
            previousMessages: [],
            actionHint: nil
        )
    }
}

/// 응답을 영원히 주지 않는 URLProtocol. 요청이 대기 중인 동안 세션을
/// 끊어서 "전송 도중 취소"를 결정적으로 재현한다.
private final class HangingURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {}
    override func stopLoading() {}
}
