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
}
