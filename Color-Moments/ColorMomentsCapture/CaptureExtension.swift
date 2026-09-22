import ExtensionKit
import Foundation
import LockedCameraCapture
import SwiftUI

/// 잠금화면에서 카메라 컨트롤 버튼으로 뜨는 촬영 확장.
///
/// 이 확장의 존재 이유는 하나다 — 기본 카메라와 진입 속도를 같게 만드는 것.
/// 잠금 해제도 앱 실행도 없이 물리 버튼 한 번으로 찍힌다.
/// 찍힌 것은 session.sessionContentURL 에 쌓이고, 본 앱이 나중에 가져간다.
@main
struct CaptureExtension: LockedCameraCaptureExtension {
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            ViewFinder(session: session)
        }
    }
}
