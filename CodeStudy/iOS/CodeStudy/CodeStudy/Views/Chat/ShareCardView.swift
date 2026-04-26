import SwiftUI

// MARK: - Share Card View

struct ShareCardView: View {
    let conceptTitle: String
    let isMastered: Bool
    let streakCount: Int
    let date: Date

    private let deepBlue = Color.deepBlue
    private let deepBlueDark = Color(hex: "0F2440")
    private let accentOrange = Color.warmOrange

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    private var headlineText: String {
        if isMastered {
            return "오늘 \(conceptTitle)을 마스터했어요!"
        } else {
            return "\(conceptTitle) 학습 완료!"
        }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [deepBlue, deepBlueDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 160)

                // App logo area
                VStack(spacing: 12) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(accentOrange)

                    Text("CodeStudy")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()
                    .frame(height: 80)

                // Concept headline
                Text(headlineText)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)

                Spacer()
                    .frame(height: 48)

                // Streak badge
                if streakCount > 0 {
                    HStack(spacing: 8) {
                        Text("\u{1F525}")
                            .font(.system(size: 36))
                        Text("\(streakCount)일 연속 학습 중")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.12))
                    )
                }

                Spacer()
                    .frame(height: 40)

                // Date
                Text(formattedDate)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                // App promo + watermark
                VStack(spacing: 8) {
                    Text(String(
                        localized: "share.card.cta",
                        defaultValue: "나도 AI로 코딩 공부하기"
                    ))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("CodeStudy — 무료 다운로드")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.bottom, 48)
            }
        }
        .frame(width: 1080, height: 1080)
    }
}

// MARK: - Share Card Renderer

struct ShareCardRenderer {
    @MainActor
    static func render(
        conceptTitle: String,
        isMastered: Bool,
        streakCount: Int,
        date: Date = Date()
    ) -> UIImage? {
        let cardView = ShareCardView(
            conceptTitle: conceptTitle,
            isMastered: isMastered,
            streakCount: streakCount,
            date: date
        )

        let renderer = ImageRenderer(
            content: cardView.frame(width: 1080, height: 1080)
        )
        renderer.scale = 1.0
        return renderer.uiImage
    }
}

// MARK: - Preview

#Preview("Mastered + Streak") {
    ShareCardView(
        conceptTitle: "Optionals",
        isMastered: true,
        streakCount: 12,
        date: Date()
    )
    .scaleEffect(0.3)
}

#Preview("Completed") {
    ShareCardView(
        conceptTitle: "클로저",
        isMastered: false,
        streakCount: 5,
        date: Date()
    )
    .scaleEffect(0.3)
}
