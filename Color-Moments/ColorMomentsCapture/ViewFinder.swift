import LockedCameraCapture
import SwiftUI

/// 잠금화면 촬영 화면. 앱과 같은 `CaptureScreen` 을 쓴다.
///
/// 저장 위치만 다르다 — 잠긴 확장은 앱 저장소에 못 쓰고 `sessionContentURL` 에만 쓸 수 있다.
/// 거기 쌓인 것은 앱이 열릴 때 `CaptureInbox` 가 가져가고 원본은 무효화된다.
///
/// 스파이크 단계에서는 `UIImagePickerController` 를 썼다(애플 템플릿). 그건 기본 카메라 UI가
/// 그대로 떠서 우리 앱처럼 보이지 않았다. 커스텀 화면으로 바꾸면서
/// `AVCaptureEventInteraction` 을 직접 붙여야 확장이 조기 종료되지 않는다 — `CaptureScreen` 참조.
struct ViewFinder: View {
    let session: LockedCameraCaptureSession
    @State private var engine: CaptureEngine

    init(session: LockedCameraCaptureSession) {
        self.session = session
        let url = session.sessionContentURL
        _engine = State(initialValue: CaptureEngine(destination: { url }))
    }

    var body: some View {
        CaptureScreen(engine: engine, showsDismissHint: true)
    }
}
