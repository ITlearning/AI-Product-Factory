import AppIntents
import SwiftUI
import WidgetKit

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
        PebbleWidget()
    }
}
