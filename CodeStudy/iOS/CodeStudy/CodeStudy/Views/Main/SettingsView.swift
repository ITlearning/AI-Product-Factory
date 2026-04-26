import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var reminderDate = Date()

    var body: some View {
        Group {
            if let viewModel, viewModel.state.isLoaded {
                settingsForm(viewModel: viewModel)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(String(localized: "settings.title", defaultValue: "설정"))
        .task {
            if viewModel == nil {
                let vm = SettingsViewModel(modelContext: modelContext)
                viewModel = vm
                await vm.handle(.loadSettings)
                updateReminderDate(from: vm)
            }
        }
    }

    // MARK: - Settings Form

    @ViewBuilder
    private func settingsForm(viewModel: SettingsViewModel) -> some View {
        Form {
            // Profile section
            Section {
                // Swift level picker
                Picker(
                    String(localized: "settings.level", defaultValue: "레벨"),
                    selection: Binding(
                        get: { viewModel.state.swiftLevel },
                        set: { newLevel in
                            Task { await viewModel.handle(.updateLevel(newLevel)) }
                        }
                    )
                ) {
                    ForEach(SwiftLevel.allCases) { level in
                        Text(level.displayName(for: viewModel.state.language)).tag(level)
                    }
                }

                // Language picker
                Picker(
                    String(localized: "settings.language", defaultValue: "언어"),
                    selection: Binding(
                        get: { viewModel.state.language },
                        set: { newLang in
                            Task { await viewModel.handle(.updateLanguage(newLang)) }
                        }
                    )
                ) {
                    Text("한국어").tag(AppLanguage.korean)
                    Text("English").tag(AppLanguage.english)
                }

                // Track picker (Cycle 3 — multi-track support)
                Picker(
                    String(localized: "settings.track", defaultValue: "학습 트랙"),
                    selection: Binding(
                        get: { viewModel.state.track },
                        set: { newTrack in
                            Task { await viewModel.handle(.updateTrack(newTrack)) }
                        }
                    )
                ) {
                    ForEach(TrackType.allCases) { track in
                        Text(track.displayName(for: viewModel.state.language)).tag(track)
                    }
                }
            } header: {
                Text(String(localized: "settings.section.profile", defaultValue: "프로필"))
            }

            // Notifications section
            Section {
                Toggle(
                    String(localized: "settings.notification.daily", defaultValue: "매일 학습 알림"),
                    isOn: Binding(
                        get: { viewModel.state.notificationEnabled },
                        set: { enabled in
                            Task { await viewModel.handle(.toggleNotifications(enabled)) }
                        }
                    )
                )

                if viewModel.state.notificationEnabled {
                    DatePicker(
                        String(localized: "settings.notification.time", defaultValue: "알림 시간"),
                        selection: $reminderDate,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: reminderDate) { _, newDate in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                        Task {
                            await viewModel.handle(
                                .updateReminderTime(
                                    hour: components.hour ?? 20,
                                    minute: components.minute ?? 0
                                )
                            )
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings.section.notifications", defaultValue: "알림"))
            }

            // About section
            Section {
                HStack {
                    Text(String(localized: "settings.version", defaultValue: "버전"))
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(String(localized: "settings.credits", defaultValue: "만든 사람"))
                    Spacer()
                    Text("Tabber")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            } header: {
                Text(String(localized: "settings.section.about", defaultValue: "앱 정보"))
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func updateReminderDate(from viewModel: SettingsViewModel) {
        var components = DateComponents()
        components.hour = viewModel.state.reminderHour
        components.minute = viewModel.state.reminderMinute
        if let date = Calendar.current.date(from: components) {
            reminderDate = date
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [UserProfile.self, DailyStreak.self, ConceptProgress.self, StudySession.self, ChatMessage.self], inMemory: true)
}
