import SwiftUI
import SwiftData

// MARK: - OnboardingView
// Container that manages the 3-step onboarding flow.

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: OnboardingViewModel(modelContext: modelContext))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: progress indicator + skip button
            HStack {
                ProgressIndicator(
                    currentStep: viewModel.state.currentStep.rawValue,
                    totalSteps: 4
                )

                // "건너뛰기" shown only on notification step
                if viewModel.state.currentStep == .notification {
                    Button {
                        Task {
                            await viewModel.handle(.skipNotifications)
                            await viewModel.handle(.completeOnboarding)
                        }
                    } label: {
                        Text(String(localized: "onboarding.skip",
                                     defaultValue: "건너뛰기"))
                            // EN: Skip
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 16)
                    .transition(.opacity)
                }
            }
            .padding(.top, 8)
            .animation(.easeInOut(duration: 0.2), value: viewModel.state.currentStep)

            // Step content
            TabView(selection: $viewModel.state.currentStep) {
                // Step 1: Experience
                ExperienceStepView(
                    selection: viewModel.state.hasDevelopmentExperience,
                    onSelect: { hasExperience in
                        viewModel.state.hasDevelopmentExperience = hasExperience
                    },
                    onNext: {
                        Task { await viewModel.handle(.setExperience(viewModel.state.hasDevelopmentExperience ?? false)) }
                    }
                )
                .tag(OnboardingViewModel.OnboardingStep.experience)

                // Step 2: Track 선택 (Cycle 3 추가)
                TrackStepView(
                    selection: viewModel.state.preferredTrack,
                    onSelect: { track in
                        viewModel.state.preferredTrack = track
                    },
                    onNext: {
                        Task { await viewModel.handle(.setTrack(viewModel.state.preferredTrack ?? .swift)) }
                    }
                )
                .tag(OnboardingViewModel.OnboardingStep.track)

                // Step 3: Swift Level
                SwiftLevelStepView(
                    selection: viewModel.state.swiftLevel,
                    onSelect: { level in
                        viewModel.state.swiftLevel = level
                    },
                    onNext: {
                        Task { await viewModel.handle(.setSwiftLevel(viewModel.state.swiftLevel ?? .beginner)) }
                    }
                )
                .tag(OnboardingViewModel.OnboardingStep.swiftLevel)

                // Step 3: Notifications
                NotificationStepView(
                    reminderHour: viewModel.state.reminderHour,
                    reminderMinute: viewModel.state.reminderMinute,
                    onTimeChange: { hour, minute in
                        Task { await viewModel.handle(.setReminderTime(hour: hour, minute: minute)) }
                    },
                    onEnable: {
                        Task {
                            await viewModel.handle(.enableNotifications)
                            await viewModel.handle(.completeOnboarding)
                        }
                    },
                    onSkip: {
                        Task {
                            await viewModel.handle(.skipNotifications)
                            await viewModel.handle(.completeOnboarding)
                        }
                    }
                )
                .tag(OnboardingViewModel.OnboardingStep.notification)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: viewModel.state.currentStep)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    // Preview requires a ModelContainer
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, configurations: config)

    OnboardingView(modelContext: container.mainContext)
        .modelContainer(container)
}
