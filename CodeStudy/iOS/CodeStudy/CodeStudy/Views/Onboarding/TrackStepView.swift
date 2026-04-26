import SwiftUI

// MARK: - TrackStepView (Onboarding Step 2 — Cycle 3)
// "어떤 트랙으로 학습하시겠어요?" — Track selection between Swift / Backend.
//
// SwiftLevelStepView와 동일한 카드 패턴 재사용. 디자인 일관성.

struct TrackStepView: View {
    let selection: TrackType?
    let onSelect: (TrackType) -> Void
    let onNext: () -> Void

    /// Onboarding 단계는 UserProfile이 아직 생성 전이라 Locale 직접 참조.
    private var language: AppLanguage {
        AppLanguage.systemDefault
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 32)

            Text(String(
                localized: "onboarding.track.title",
                defaultValue: "어떤 분야를 학습하시겠어요?"
            ))
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(Color.deepBlue)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            Text(String(
                localized: "onboarding.track.subtitle",
                defaultValue: "나중에 설정에서 언제든 바꿀 수 있어요"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
            .padding(.horizontal, 24)

            Spacer()
                .frame(height: 32)

            VStack(spacing: 12) {
                ForEach(TrackType.allCases) { track in
                    trackCard(
                        track: track,
                        isSelected: selection == track
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                onNext()
            } label: {
                Text(String(localized: "onboarding.next", defaultValue: "다음"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selection != nil ? Color.warmOrange : Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selection == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func trackCard(track: TrackType, isSelected: Bool) -> some View {
        Button {
            onSelect(track)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: track.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.warmOrange : Color.deepBlue.opacity(0.6))
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.displayName(for: language))
                        .font(.headline)
                        .foregroundStyle(Color.deepBlue)

                    Text(track.tagline(for: language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        // 카피 길이 제각각이라 1줄 강제 + 자동 축소.
                        // UIKit의 adjustsFontSizeToFitWidth + minimumScaleFactor 조합.
                        // 0.7 = 최대 70%까지 축소. 그 이상은 truncate.
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.warmOrange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.warmOrange.opacity(0.08) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.warmOrange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    TrackStepView(
        selection: .swift,
        onSelect: { _ in },
        onNext: {}
    )
}
