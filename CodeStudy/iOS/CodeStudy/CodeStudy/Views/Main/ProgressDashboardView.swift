import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ProgressViewModel?
    @Query private var streaks: [DailyStreak]

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.state.concepts.isEmpty && !viewModel.state.totalStudied.isMultiple(of: 1) {
                    // Still loading — show spinner briefly
                    ProgressView()
                        .controlSize(.large)
                } else if viewModel.state.concepts.isEmpty {
                    emptyState
                } else {
                    progressContent(viewModel: viewModel)
                }
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(String(localized: "progress.title", defaultValue: "학습 기록"))
        .task {
            if viewModel == nil {
                let vm = ProgressViewModel(modelContext: modelContext)
                viewModel = vm
                await vm.handle(.loadProgress)
            }
        }
    }

    // MARK: - Progress Content

    @ViewBuilder
    private func progressContent(viewModel: ProgressViewModel) -> some View {
        List {
            // Stats summary section
            Section {
                statsRow(viewModel: viewModel)
            }

            // Calendar heatmap placeholder
            Section {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.deepBlue)
                    Text(String(localized: "progress.calendar.placeholder", defaultValue: "학습 캘린더는 다음 업데이트에서!"))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text(String(localized: "progress.calendar.header", defaultValue: "학습 캘린더"))
            }

            // Concept list grouped by category
            let grouped = Dictionary(grouping: viewModel.state.concepts, by: \.category)
            let sortedKeys = grouped.keys.sorted()

            ForEach(sortedKeys, id: \.self) { category in
                Section {
                    ForEach(grouped[category] ?? []) { item in
                        conceptRow(item: item)
                    }
                } header: {
                    Text(category)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Stats Row

    @ViewBuilder
    private func statsRow(viewModel: ProgressViewModel) -> some View {
        HStack(spacing: 0) {
            statItem(
                value: "\(viewModel.state.totalStudied)",
                label: String(localized: "progress.stat.studied", defaultValue: "학습 완료"),
                icon: "book.closed.fill",
                color: .deepBlue
            )

            Divider()
                .frame(height: 40)

            statItem(
                value: "\(viewModel.state.totalMastered)",
                label: String(localized: "progress.stat.mastered", defaultValue: "마스터"),
                icon: "star.fill",
                color: .warmOrange
            )

            Divider()
                .frame(height: 40)

            statItem(
                value: "\(streaks.first?.currentStreak ?? 0)",
                label: String(localized: "progress.stat.streak", defaultValue: "연속"),
                icon: "flame.fill",
                color: .warmOrange
            )
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Concept Row

    @ViewBuilder
    private func conceptRow(item: ProgressViewModel.ConceptProgressItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                Text("\(item.studiedCount)회 학습")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: item.isMastered ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isMastered ? Color.warmOrange : .secondary)
                .font(.title3)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "progress.empty.title", defaultValue: "아직 학습한 개념이 없어요"),
                systemImage: "text.book.closed"
            )
        } description: {
            Text(String(localized: "progress.empty.subtitle", defaultValue: "첫 학습을 시작해볼까요?"))
        }
    }
}

#Preview {
    NavigationStack {
        ProgressDashboardView()
    }
    .modelContainer(for: [UserProfile.self, DailyStreak.self, ConceptProgress.self, StudySession.self, ChatMessage.self], inMemory: true)
}
