import SwiftUI
import SwiftData

struct SessionCompleteView: View {
    let isMastered: Bool
    let session: StudySession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var displayedStreak: Int = 0
    @State private var animateIcon = false

    // Design tokens
    private let accentColor = Color(hex: "FF6B35")
    private let deepBlue = Color(hex: "1E3A5F")

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Icon
            iconSection

            // Title & subtitle
            titleSection

            // Session summary
            summarySection

            // Streak counter
            streakSection

            Spacer()

            // Action buttons
            buttonSection
        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.4)) {
                animateIcon = true
            }
            animateStreakCounter()
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconSection: some View {
        if isMastered {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(accentColor)
                .scaleEffect(animateIcon ? 1.0 : 0.3)
                .opacity(animateIcon ? 1.0 : 0.0)
        } else {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 64))
                .foregroundStyle(deepBlue)
                .scaleEffect(animateIcon ? 1.0 : 0.5)
                .opacity(animateIcon ? 1.0 : 0.0)
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text(isMastered
                 ? String(localized: "complete.mastered.title", defaultValue: "이 개념을 마스터했어요!")
                 : String(localized: "complete.manual.title", defaultValue: "학습을 마쳤어요"))
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if !isMastered {
                Text(String(localized: "complete.manual.subtitle",
                            defaultValue: "마스터하려면 다시 도전해보세요"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundStyle(.secondary)
                Text("\(session.turnCount)회 대화")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let duration = session.duration {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text(formattedDuration(duration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Streak

    private var streakSection: some View {
        VStack(spacing: 4) {
            Text(String(localized: "complete.streak.label", defaultValue: "연속 학습"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(accentColor)
                Text("\(displayedStreak)")
                    .font(.title.bold().monospacedDigit())
                    .contentTransition(.numericText())
                Text(String(localized: "complete.streak.days", defaultValue: "일"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Text(String(localized: "complete.home", defaultValue: "홈으로"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(deepBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if !isMastered {
                Button {
                    dismiss()
                    // Parent view handles retry navigation
                } label: {
                    Text(String(localized: "complete.retry", defaultValue: "다시 도전"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(accentColor)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(accentColor, lineWidth: 1.5)
                        )
                }
            }
        }
    }

    // MARK: - Helpers

    private func animateStreakCounter() {
        let targetStreak = fetchCurrentStreak()
        guard targetStreak > 0 else {
            displayedStreak = 0
            return
        }

        // Count-up animation
        let stepDuration = 0.4 / Double(targetStreak)
        for i in 1...targetStreak {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.snappy) {
                    displayedStreak = i
                }
            }
        }
    }

    private func fetchCurrentStreak() -> Int {
        let descriptor = FetchDescriptor<DailyStreak>()
        let streaks = (try? modelContext.fetch(descriptor)) ?? []
        return streaks.first?.currentStreak ?? 0
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes)분 \(seconds)초"
        }
        return "\(seconds)초"
    }
}

#Preview("Mastered") {
    SessionCompleteView(
        isMastered: true,
        session: StudySession(conceptID: "optionals", conceptTitle: "옵셔널")
    )
}

#Preview("Manual") {
    SessionCompleteView(
        isMastered: false,
        session: StudySession(conceptID: "optionals", conceptTitle: "옵셔널")
    )
}
