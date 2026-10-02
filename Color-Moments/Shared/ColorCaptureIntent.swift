import AppIntents

struct ColorCaptureIntent: CameraCaptureIntent {
    static let title: LocalizedStringResource = "색 남기기"
    static let description = IntentDescription("지금 이 순간의 색을 남깁니다.")

    /// 앱 본체만 꽂는다 — 잠금이 풀린 채 이 인텐트로 열린 앱은 몇 초 안에 카메라가 안 돌면 시스템이 죽인다(README 카메라 컨트롤 절).
    nonisolated(unsafe) static var opensApp: (@MainActor () -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        CaptureEngine.log.notice("capture intent performed, opensApp=\(Self.opensApp != nil, privacy: .public)")
        Self.opensApp?()
        return .result()
    }
}
