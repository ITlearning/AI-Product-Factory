import AppIntents

/// 「나는 카메라 앱이다」 선언.
///
/// LockedCameraCapture 확장만으로는 **설정 > 카메라 > 카메라 컨트롤 목록에 뜨지 않는다**
/// (2026-09-22 실기기 확인: 확장만 넣었을 때 목록에 없었다).
/// 시스템이 이 인텐트를 보고 카메라 앱으로 인식한다.
///
/// 앱과 확장이 같은 타입을 봐야 하므로 두 타깃에 함께 포함한다.
struct ColorCaptureIntent: CameraCaptureIntent {
    static let title: LocalizedStringResource = "색 남기기"
    static let description = IntentDescription("지금 이 순간의 색을 남깁니다.")

    func perform() async throws -> some IntentResult {
        .result()
    }
}
