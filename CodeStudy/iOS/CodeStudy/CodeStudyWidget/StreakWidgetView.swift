import SwiftUI
import WidgetKit

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: StreakEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SystemSmallView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        default:
            SystemSmallView(entry: entry)
        }
    }
}

// MARK: - System Small (Home Screen)

private struct SystemSmallView: View {
    let entry: StreakEntry

    private let deepBlue = Color(red: 0.08, green: 0.12, blue: 0.28)
    private let flameOrange = Color(red: 1.0, green: 0.55, blue: 0.0)

    var body: some View {
        ZStack {
            deepBlue

            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: entry.isStudiedToday ? "flame.fill" : "flame")
                        .font(.title2)
                        .foregroundStyle(flameOrange)

                    Text("\(entry.streakCount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                if let title = entry.conceptTitle {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }

                Text(entry.isStudiedToday ? "오늘 학습 완료" : "학습 시작")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(entry.isStudiedToday ? .white.opacity(0.6) : flameOrange)
            }
            .padding(12)
        }
    }
}

// MARK: - Accessory Circular (Lock Screen)

private struct AccessoryCircularView: View {
    let entry: StreakEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 2) {
                Image(systemName: entry.isStudiedToday ? "flame.fill" : "flame")
                    .font(.system(size: 14))

                Text("\(entry.streakCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .widgetAccentable()
        }
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    StudyStreakWidget()
} timeline: {
    StreakEntry(date: .now, streakCount: 12, conceptTitle: "옵셔널 체이닝", isStudiedToday: true)
    StreakEntry(date: .now, streakCount: 0, conceptTitle: nil, isStudiedToday: false)
}

#Preview("Circular", as: .accessoryCircular) {
    StudyStreakWidget()
} timeline: {
    StreakEntry(date: .now, streakCount: 12, conceptTitle: nil, isStudiedToday: true)
    StreakEntry(date: .now, streakCount: 0, conceptTitle: nil, isStudiedToday: false)
}
