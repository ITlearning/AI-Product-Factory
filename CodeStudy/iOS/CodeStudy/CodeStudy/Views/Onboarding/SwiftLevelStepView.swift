import SwiftUI

// MARK: - SwiftLevelStepView (Step 2)
// "Swift 경험은 어느 정도인가요?" — How much Swift experience do you have?

struct SwiftLevelStepView: View {
    let selection: SwiftLevel?
    let onSelect: (SwiftLevel) -> Void
    let onNext: () -> Void

    // Design tokens
    private let deepBlue = Color(hex: "1E3A5F")
    private let accent = Color(hex: "FF6B35")

    private var levelData: [(SwiftLevel, String, String, String)] {
        [
            // (level, title, description, SF Symbol)
            (.beginner,
             String(localized: "onboarding.level.beginner", defaultValue: "처음"),
             // EN: Beginner
             String(localized: "onboarding.level.beginner.desc", defaultValue: "Swift를 처음 접해요"),
             // EN: Completely new to Swift
             "leaf"),

            (.basic,
             String(localized: "onboarding.level.basic", defaultValue: "기초"),
             // EN: Basic
             String(localized: "onboarding.level.basic.desc", defaultValue: "변수, 조건문 정도는 알아요"),
             // EN: I know variables and conditionals
             "text.book.closed"),

            (.intermediate,
             String(localized: "onboarding.level.intermediate", defaultValue: "중급"),
             // EN: Intermediate
             String(localized: "onboarding.level.intermediate.desc", defaultValue: "프로토콜, 제네릭을 써봤어요"),
             // EN: I've used protocols and generics
             "hammer"),

            (.advanced,
             String(localized: "onboarding.level.advanced", defaultValue: "고급"),
             // EN: Advanced
             String(localized: "onboarding.level.advanced.desc", defaultValue: "Concurrency, Macro를 공부하고 싶어요"),
             // EN: I want to study Concurrency and Macros
             "bolt"),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 32)

            // Title
            Text(String(localized: "onboarding.level.title",
                         defaultValue: "Swift 경험은 어느 정도인가요?"))
                // EN: How much Swift experience do you have?
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(deepBlue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
                .frame(height: 32)

            // Level cards
            VStack(spacing: 12) {
                ForEach(levelData, id: \.0) { level, title, description, icon in
                    levelCard(
                        level: level,
                        title: title,
                        description: description,
                        icon: icon,
                        isSelected: selection == level
                    )
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
                    .background(selection != nil ? accent : Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selection == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Card Builder

    @ViewBuilder
    private func levelCard(
        level: SwiftLevel,
        title: String,
        description: String,
        icon: String,
        isSelected: Bool
    ) -> some View {
        Button {
            onSelect(level)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? accent : deepBlue.opacity(0.6))
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(deepBlue)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accent.opacity(0.08) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    SwiftLevelStepView(
        selection: .basic,
        onSelect: { _ in },
        onNext: {}
    )
}
