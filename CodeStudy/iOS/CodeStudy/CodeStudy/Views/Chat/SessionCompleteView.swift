import SwiftUI
import SwiftData

struct SessionCompleteView: View {
    let isMastered: Bool
    let session: StudySession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var displayedStreak: Int = 0
    @State private var animateIcon = false
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    // Design tokens
    private let accentColor = Color.warmOrange
    private let deepBlue = Color.deepBlue

    /// Changing this ID re-creates the ConfettiView, triggering a new burst.
    /// This is the easter egg: tap the background → new confetti explosion.
    @State private var confettiID = UUID()

    var body: some View {
        ZStack {
            // Background tap area for easter egg (behind buttons)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    // Change ID → SwiftUI destroys + recreates ConfettiView → onAppear fires → new burst
                    confettiID = UUID()
                }

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

                // Action buttons (above background, receive taps normally)
                buttonSection
            }
            .padding(24)

            // Confetti layer — passthrough, doesn't block taps
            if isMastered {
                ConfettiView(particleCount: 100, duration: 3.0)
                    .id(confettiID)  // Easter egg: new ID = new burst
                    .ignoresSafeArea()
            }
        }
        .interactiveDismissDisabled(false)
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

            // Share button
            Button {
                shareImage = ShareCardRenderer.render(
                    conceptTitle: session.conceptTitle,
                    isMastered: isMastered,
                    streakCount: displayedStreak
                )
                if shareImage != nil {
                    showShareSheet = true
                }
            } label: {
                Label(
                    String(localized: "complete.share", defaultValue: "공유하기"),
                    systemImage: "square.and.arrow.up"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(deepBlue)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(deepBlue, lineWidth: 1.5)
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareImage {
                    ShareSheet(items: [shareImage])
                }
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

// MARK: - UIActivityViewController Wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
