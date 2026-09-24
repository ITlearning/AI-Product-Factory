import AppIntents

struct ColorCaptureIntent: CameraCaptureIntent {
    static let title: LocalizedStringResource = "색 남기기"
    static let description = IntentDescription("지금 이 순간의 색을 남깁니다.")

    func perform() async throws -> some IntentResult {
        .result()
    }
}
