import AppIntents
import SwiftUI
import WidgetKit

/// 제어 센터·잠금화면·카메라 컨트롤에 올라가는 컨트롤.
///
/// **이게 없으면 설정 > 카메라 > 카메라 컨트롤에서 앱이 보여도 선택되지 않는다**
/// (2026-09-22 iPhone 16 Pro 실측). 애플 문서:
/// "Create a control widget that launches the capture extension when the device is locked.
///  Include the CameraCaptureIntent in your app target, control widget extension target,
///  and camera capture extension target."
///
/// 즉 인텐트는 세 타깃 모두에, 컨트롤은 이 타깃에 있어야 한다.
struct ColorCaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.itlearning.colormoments.capture-control") {
            ControlWidgetButton(action: ColorCaptureIntent()) {
                Label("색 남기기", systemImage: "camera.aperture")
            }
        }
        .displayName("몽돌")
        .description("지금 이 순간의 색을 남깁니다.")
    }
}

@main
struct ColorMomentsControlBundle: WidgetBundle {
    var body: some Widget {
        ColorCaptureControl()
    }
}
