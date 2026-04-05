import WidgetKit
import SwiftUI

struct StudyStreakWidget: Widget {
    let kind = "StudyStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("학습 스트릭")
        .description("오늘의 Swift 개념과 연속 학습일을 확인하세요")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}
