import SwiftUI

// MARK: - SwiftLevelStepView (Step 2)
// "Swift 경험은 어느 정도인가요?" — How much Swift experience do you have?

struct SwiftLevelStepView: View {
    let selection: SwiftLevel?
    let track: TrackType  // Cycle 3 — 트랙별 다른 카피 노출
    let onSelect: (SwiftLevel) -> Void
    let onNext: () -> Void

    /// 트랙에 맞는 level 카드 데이터.
    private var levelData: [(SwiftLevel, String, String, String)] {
        switch track {
        case .swift:
            return swiftLevelData
        case .backend:
            return backendLevelData
        }
    }

    private var swiftLevelData: [(SwiftLevel, String, String, String)] {
        [
            (.beginner,
             String(localized: "onboarding.level.beginner", defaultValue: "처음"),
             String(localized: "onboarding.level.beginner.desc", defaultValue: "Swift를 처음 접해요"),
             "leaf"),
            (.basic,
             String(localized: "onboarding.level.basic", defaultValue: "기초"),
             String(localized: "onboarding.level.basic.desc", defaultValue: "변수, 조건문 정도는 알아요"),
             "text.book.closed"),
            (.intermediate,
             String(localized: "onboarding.level.intermediate", defaultValue: "중급"),
             String(localized: "onboarding.level.intermediate.desc", defaultValue: "프로토콜, 제네릭을 써봤어요"),
             "hammer"),
            (.advanced,
             String(localized: "onboarding.level.advanced", defaultValue: "고급"),
             String(localized: "onboarding.level.advanced.desc", defaultValue: "Concurrency, Macro를 공부하고 싶어요"),
             "bolt"),
        ]
    }

    private var backendLevelData: [(SwiftLevel, String, String, String)] {
        [
            (.beginner,
             String(localized: "onboarding.level.beginner", defaultValue: "처음"),
             String(localized: "onboarding.level.backend.beginner.desc",
                    defaultValue: "Spring/Kotlin을 처음 접해요"),
             "leaf"),
            (.basic,
             String(localized: "onboarding.level.basic", defaultValue: "기초"),
             String(localized: "onboarding.level.backend.basic.desc",
                    defaultValue: "기본 CRUD API는 만들어봤어요"),
             "text.book.closed"),
            (.intermediate,
             String(localized: "onboarding.level.intermediate", defaultValue: "중급"),
             String(localized: "onboarding.level.backend.intermediate.desc",
                    defaultValue: "JPA, 트랜잭션 운영 경험 있어요"),
             "hammer"),
            (.advanced,
             String(localized: "onboarding.level.advanced", defaultValue: "고급"),
             String(localized: "onboarding.level.backend.advanced.desc",
                    defaultValue: "대규모 시스템 설계를 공부하고 싶어요"),
             "bolt"),
        ]
    }

    /// 트랙별 헤더 타이틀.
    private var titleText: String {
        switch track {
        case .swift:
            return String(localized: "onboarding.level.title",
                          defaultValue: "Swift 경험은 어느 정도인가요?")
        case .backend:
            return String(localized: "onboarding.level.title.backend",
                          defaultValue: "백엔드 경험은 어느 정도인가요?")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 32)

            // Title (track-aware)
            Text(titleText)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.deepBlue)
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
                    .foregroundStyle(isSelected ? Color.warmOrange : Color.deepBlue.opacity(0.6))
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.deepBlue)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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

#Preview("Swift") {
    SwiftLevelStepView(
        selection: .basic,
        track: .swift,
        onSelect: { _ in },
        onNext: {}
    )
}

#Preview("Backend") {
    SwiftLevelStepView(
        selection: .basic,
        track: .backend,
        onSelect: { _ in },
        onNext: {}
    )
}
