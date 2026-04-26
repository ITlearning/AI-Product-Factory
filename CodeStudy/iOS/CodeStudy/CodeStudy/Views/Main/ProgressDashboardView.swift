import SwiftUI
import SwiftData
import TipKit

struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ProgressViewModel?
    @Query private var streaks: [DailyStreak]
    @Query private var profiles: [UserProfile]

    /// Curriculum 즉시 로드. 목록의 개념 제목을 사용자 트랙·언어로 즉석 변환.
    /// Cycle 3 — 백엔드 트랙 사용자도 자기 트랙 JSON을 읽도록 track 주입.
    private var curriculum: ConceptCurriculum {
        ConceptCurriculum(track: profiles.first?.track ?? .swift)
    }

    private var language: AppLanguage {
        profiles.first?.language ?? .korean
    }

    /// 저장된 conceptTitle 대신 curriculum lookup으로 사용자 언어 표시.
    /// 기존 사용자가 한글로 저장한 ConceptProgress도 실시간 영문 노출 가능.
    private func displayTitle(for item: ProgressViewModel.ConceptProgressItem) -> String {
        if let concept = curriculum.conceptByID(item.id) {
            return concept.title(for: language)
        }
        return item.title
    }

    /// Cycle 2 신규 기능 안내 — 마스터한 개념 탭하면 학습 여정 볼 수 있다.
    /// TipKit이 표시 조건 / dismiss 영구화 / 빈도 조절을 알아서 처리.
    private let conceptHistoryTip = ConceptHistoryTip()

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.state.isLoading && viewModel.state.concepts.isEmpty {
                    // Initial load in progress — show spinner.
                    // (Replaces dead `!isMultiple(of: 1)` heuristic which
                    // was always false for any Int.)
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        // Lane B's ConceptHistoryView is the destination. Tapping a concept
        // row pushes its history. Typed value = String (conceptId).
        .navigationDestination(for: String.self) { conceptId in
            ConceptHistoryView(conceptId: conceptId)
        }
        .task {
            if viewModel == nil {
                let vm = ProgressViewModel(modelContext: modelContext)
                viewModel = vm
                await vm.handle(.loadProgress)
            }
            // TipKit Rule 평가용 — 마스터 1개라도 있으면 tip 노출 자격.
            ConceptHistoryTip.hasMasteredConcepts = (viewModel?.state.totalMastered ?? 0) > 0
        }
        .onAppear {
            if let vm = viewModel {
                Task { await vm.handle(.loadProgress) }
            }
        }
        // 사용자가 Settings에서 트랙 전환하면 즉시 기록 탭 갱신.
        // .preferredTrack 변화를 감지해서 loadProgress 재실행.
        .onChange(of: profiles.first?.preferredTrack) { _, _ in
            if let vm = viewModel {
                Task { await vm.handle(.loadProgress) }
            }
        }
        .onChange(of: viewModel?.state.totalMastered) { _, newValue in
            ConceptHistoryTip.hasMasteredConcepts = (newValue ?? 0) > 0
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

            // Calendar heatmap
            Section {
                CalendarHeatmapView(studyData: viewModel.state.streakData)
            } header: {
                Text(String(localized: "progress.calendar.header", defaultValue: "학습 캘린더"))
            }

            // Cycle 2 신규 기능 안내 (TipKit). hasMasteredConcepts == true일 때만
            // 자동 노출. 사용자가 dismiss하면 TipKit이 영구히 안 띄움.
            Section {
                TipView(conceptHistoryTip)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // Concept list grouped by category
            let grouped = Dictionary(grouping: viewModel.state.concepts, by: \.category)
            let sortedKeys = grouped.keys.sorted()

            ForEach(sortedKeys, id: \.self) { category in
                Section {
                    ForEach(grouped[category] ?? []) { item in
                        // NavigationLink(value:) pairs with the
                        // .navigationDestination(for: String.self) above.
                        // SwiftUI auto-renders the trailing chevron.
                        NavigationLink(value: item.id) {
                            conceptRow(item: item)
                        }
                    }
                } header: {
                    Text(category)
                }
            }
        }
        .listStyle(.insetGrouped)
        // Section 사이 기본 간격이 너무 커서 tip 카드 위아래로 빈 공간 생김.
        // .compact으로 압축해서 시각적 흐름 자연스럽게.
        .listSectionSpacing(.compact)
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
                Text(displayTitle(for: item))
                    .font(.body)
                // Xcode가 자동으로 "%lld회 학습"으로 키 추출.
                // xcstrings에 ko/en 둘 다 등록됨 ("%lld sessions").
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
