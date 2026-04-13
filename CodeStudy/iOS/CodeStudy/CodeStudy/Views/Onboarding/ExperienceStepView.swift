import SwiftUI

// MARK: - ExperienceStepView (Step 1)
// "개발 경험이 있으신가요?" — Do you have development experience?

struct ExperienceStepView: View {
    let selection: Bool?
    let onSelect: (Bool) -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 32)

            // Title
            Text(String(localized: "onboarding.experience.title",
                         defaultValue: "개발 경험이 있으신가요?"))
                // EN: Do you have coding experience?
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.deepBlue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Subtitle
            Text(String(localized: "onboarding.experience.subtitle",
                         defaultValue: "학습 난이도를 맞추기 위해 여쭤봐요"))
                // EN: We ask to tailor the difficulty for you
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.horizontal, 24)

            Spacer()
                .frame(height: 40)

            // Selection cards
            VStack(spacing: 16) {
                experienceCard(
                    title: String(localized: "onboarding.experience.yes",
                                  defaultValue: "있어요"),
                    // EN: Yes
                    icon: "chevron.left.forwardslash.chevron.right",
                    isSelected: selection == true
                ) {
                    onSelect(true)
                }

                experienceCard(
                    title: String(localized: "onboarding.experience.no",
                                  defaultValue: "처음이에요"),
                    // EN: First time
                    icon: "sparkles",
                    isSelected: selection == false
                ) {
                    onSelect(false)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Next button
            Button {
                onNext()
            } label: {
                Text(String(localized: "onboarding.next",
                             defaultValue: "다음"))
                    // EN: Next
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

    // MARK: - Card Builder

    @ViewBuilder
    private func experienceCard(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? Color.warmOrange : Color.deepBlue.opacity(0.6))
                    .frame(width: 48)

                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.deepBlue)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.warmOrange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.warmOrange.opacity(0.08) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.warmOrange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    ExperienceStepView(
        selection: true,
        onSelect: { _ in },
        onNext: {}
    )
}
