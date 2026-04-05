import SwiftUI
import SwiftData

struct DailyChallengeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DailyChallengeViewModel?
    @State private var navigateToChat = false

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.state.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let concept = viewModel.state.todayConcept {
                    conceptContent(concept: concept, viewModel: viewModel)
                } else {
                    emptyState
                }
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(String(localized: "dailyChallenge.title", defaultValue: "오늘의 학습"))
        .task {
            if viewModel == nil {
                let vm = DailyChallengeViewModel(
                    curriculum: ConceptCurriculum(),
                    modelContext: modelContext
                )
                viewModel = vm
                await vm.handle(.loadTodayConcept)
            }
        }
    }

    // MARK: - Concept Content

    @ViewBuilder
    private func conceptContent(concept: Concept, viewModel: DailyChallengeViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Streak badge
                StreakBadge(
                    currentStreak: viewModel.state.streak,
                    longestStreak: viewModel.state.longestStreak
                )
                .padding(.top, 8)

                // Concept card
                conceptCard(concept: concept, tip: viewModel.state.dailyTip)

                // Start button or completion message
                if viewModel.state.canStartSession {
                    startButton(viewModel: viewModel)
                } else {
                    dailyLimitReached
                }
            }
            .padding()
        }
    }

    // MARK: - Concept Card

    @ViewBuilder
    private func conceptCard(concept: Concept, tip: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category & level tags
            HStack(spacing: 8) {
                Text(concept.category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.deepBlue.opacity(0.1))
                    .foregroundStyle(Color.deepBlue)
                    .clipShape(Capsule())

                Text(SwiftLevel(rawValue: concept.level)?.displayName_ko ?? concept.level)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(levelColor(concept.level).opacity(0.15))
                    .foregroundStyle(levelColor(concept.level))
                    .clipShape(Capsule())
            }

            // Concept title
            Text(concept.titleKo)
                .font(.title2)
                .fontWeight(.bold)

            // Description
            Text(concept.teachingHintsKo.what)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Daily tip
            if let tip {
                Divider()

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Color.warmOrange)
                    Text(tip)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Start Button

    @ViewBuilder
    private func startButton(viewModel: DailyChallengeViewModel) -> some View {
        Button {
            Task {
                await viewModel.handle(.startSession)
                if viewModel.activeSession != nil {
                    navigateToChat = true
                }
            }
        } label: {
            Text(String(localized: "dailyChallenge.start", defaultValue: "학습 시작"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.warmOrange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .navigationDestination(isPresented: $navigateToChat) {
            // ChatView will be provided by Sprint 3-D
            Text("ChatView Placeholder")
        }
    }

    // MARK: - Daily Limit Reached

    private var dailyLimitReached: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.deepBlue)

            Text(String(localized: "dailyChallenge.completed", defaultValue: "오늘 학습을 모두 완료했어요!"))
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(String(localized: "dailyChallenge.comeBack", defaultValue: "내일 다시 만나요"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "graduationcap.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.warmOrange.opacity(0.7))

            Text(String(localized: "dailyChallenge.empty.title", defaultValue: "첫 번째 Swift 여정을 시작해볼까요?"))
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(String(localized: "dailyChallenge.empty.subtitle", defaultValue: "매일 하나의 개념을 AI와 함께 배워요"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                // Reload to try fetching a concept
                Task {
                    await viewModel?.handle(.loadTodayConcept)
                }
            } label: {
                Text(String(localized: "dailyChallenge.start", defaultValue: "학습 시작"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.warmOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private func levelColor(_ level: String) -> Color {
        switch level {
        case "beginner": return .green
        case "basic": return .blue
        case "intermediate": return .orange
        case "advanced": return .red
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        DailyChallengeView()
    }
    .modelContainer(for: [UserProfile.self, DailyStreak.self, ConceptProgress.self, StudySession.self, ChatMessage.self], inMemory: true)
}
