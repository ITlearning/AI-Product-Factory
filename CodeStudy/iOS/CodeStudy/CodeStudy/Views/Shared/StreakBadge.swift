import SwiftUI

struct StreakBadge: View {
    let currentStreak: Int
    let longestStreak: Int

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 4) {
            if currentStreak > 0 {
                Image(systemName: "flame.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.warmOrange)
                    .scaleEffect(isPulsing ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatCount(3, autoreverses: true),
                        value: isPulsing
                    )

                Text("\(currentStreak)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))

                Text(String(localized: "streak.days", defaultValue: "일 연속"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if longestStreak > currentStreak {
                    Text("최장 \(longestStreak)일")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.warmOrange)

                Text(String(localized: "streak.firstDay", defaultValue: "오늘이 첫 날이에요!"))
                    .font(.headline)
            }
        }
        .onAppear {
            if currentStreak > 0 {
                isPulsing = true
            }
        }
    }
}

#Preview("Active Streak") {
    StreakBadge(currentStreak: 7, longestStreak: 12)
}

#Preview("First Day") {
    StreakBadge(currentStreak: 0, longestStreak: 0)
}
