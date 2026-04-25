import SwiftUI
import SwiftData

/// Per-concept learning history. Pushed from `ProgressDashboardView`
/// (Lane C wires up the `.navigationDestination(for: ConceptID.self)`).
///
/// Layout (per design doc 2026-04-25):
/// - Header: concept title + ⭐ 마스터 badge if mastered
/// - Stats row: 학습 횟수, 마지막 학습일 (reuses `ProgressDashboardView` pattern)
/// - Session list: rows of `SessionRowView`, tap → `SessionConversationView`
/// - Empty state: `ContentUnavailableView` + "지금 학습하기" CTA
struct ConceptHistoryView: View {
    let conceptId: String

    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [StudySession]
    @Query private var progressEntries: [ConceptProgress]
    @Query private var profiles: [UserProfile]

    @State private var isLoading = true

    /// Curriculum 즉시 로드. 사용자 언어에 맞는 JSON을 골라 읽음.
    private let curriculum = ConceptCurriculum()

    /// 사용자 설정 언어. UserProfile이 없으면(첫 실행) 한국어 fallback.
    private var language: AppLanguage {
        profiles.first?.language ?? .korean
    }

    init(conceptId: String) {
        self.conceptId = conceptId

        // Fetch every session for this concept, newest first.
        let predicate = #Predicate<StudySession> { session in
            session.conceptID == conceptId
        }
        _sessions = Query(
            filter: predicate,
            sort: [SortDescriptor(\StudySession.startedAt, order: .reverse)]
        )

        let progressPredicate = #Predicate<ConceptProgress> { entry in
            entry.conceptID == conceptId
        }
        _progressEntries = Query(filter: progressPredicate)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessions.isEmpty {
                emptyState
            } else {
                content
            }
        }
        // 개념 이름이 그대로 nav 타이틀이 됨. body에 중복 헤더 안 두는 iOS 표준.
        .navigationTitle(conceptTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isMastered {
                ToolbarItem(placement: .topBarTrailing) {
                    masterBadge
                }
            }
        }
        .task {
            // Tiny delay avoids flashing the spinner when SwiftData
            // returns instantly. After ~0.3s we commit to whichever
            // state the @Query resolved to.
            try? await Task.sleep(nanoseconds: 300_000_000)
            isLoading = false
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        List {
            // 첫 섹션은 통계 카드만. 개념 이름은 nav 타이틀로 이동.
            // 이전 레이아웃은 body header + nav title 중복으로 상단이 잘려 보임.
            Section {
                statsRow
                    .listRowSeparator(.hidden)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(headerAccessibilityLabel)

            Section {
                ForEach(sessions) { session in
                    NavigationLink(value: session.id) {
                        SessionRowView(session: session)
                    }
                }
            } header: {
                let sessionsLabel = String(
                    localized: "concept.history.sessions.header.label",
                    defaultValue: "세션"
                )
                Text("\(sessionsLabel) (\(sessions.count))")
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: UUID.self) { sessionID in
            if let session = sessions.first(where: { $0.id == sessionID }) {
                SessionConversationView(session: session)
            }
        }
    }

    // MARK: - Master badge (toolbar)

    private var masterBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption)
            Text(String(
                localized: "concept.history.mastered.badge",
                defaultValue: "마스터"
            ))
            .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.warmOrange)
        .clipShape(Capsule())
    }

    // MARK: - Stats Row

    @ViewBuilder
    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                value: "\(sessions.count)",
                label: String(
                    localized: "concept.history.stat.studied",
                    defaultValue: "학습 횟수"
                ),
                icon: "book.closed.fill",
                color: .deepBlue
            )

            Divider()
                .frame(height: 40)

            statItem(
                value: lastStudiedRelative,
                label: String(
                    localized: "concept.history.stat.lastStudied",
                    defaultValue: "마지막"
                ),
                icon: "clock.fill",
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
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(
                    localized: "concept.history.empty.title",
                    defaultValue: "아직 학습한 기록이 없어요"
                ),
                systemImage: "text.book.closed"
            )
        } description: {
            Text(String(
                localized: "concept.history.empty.subtitle",
                defaultValue: "이 개념을 처음 학습해보세요"
            ))
        } actions: {
            // Lane C wires this up to deep-link into ChatView.
            // For Lane B we post a NotificationCenter event so the
            // RootView/MainTabView can route it without a hard dep.
            Button {
                NotificationCenter.default.post(
                    name: .conceptHistoryStartLearning,
                    object: nil,
                    userInfo: ["conceptID": conceptId]
                )
            } label: {
                Text(String(
                    localized: "concept.history.empty.cta",
                    defaultValue: "지금 학습하기"
                ))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.warmOrange)
        }
    }

    // MARK: - Derived

    private var conceptTitle: String {
        // 1순위: curriculum에서 사용자 언어로 lookup. 영문 사용자에게도 정확히 표시.
        if let concept = curriculum.conceptByID(conceptId) {
            return concept.title(for: language)
        }
        // 2순위: 저장된 stored title (마이그레이션 시점에 Korean으로 저장된 것).
        if let progress = progressEntries.first {
            return progress.conceptTitle
        }
        if let session = sessions.first {
            return session.conceptTitle
        }
        return conceptId
    }

    private var isMastered: Bool {
        progressEntries.first?.isMastered ?? false
    }

    private var lastStudiedRelative: String {
        guard let mostRecent = sessions.first?.startedAt else {
            return String(
                localized: "concept.history.stat.lastStudied.never",
                defaultValue: "—"
            )
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: mostRecent, relativeTo: Date())
    }

    private var headerAccessibilityLabel: String {
        var parts: [String] = [conceptTitle]
        if isMastered {
            parts.append(String(
                localized: "concept.history.a11y.mastered",
                defaultValue: "마스터 완료"
            ))
        }
        let studiedSuffix = String(
            localized: "concept.history.a11y.studied.suffix",
            defaultValue: "회 학습"
        )
        parts.append("\(sessions.count)\(studiedSuffix)")
        parts.append(lastStudiedRelative)
        return parts.joined(separator: ", ")
    }
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted when the user taps "지금 학습하기" from the empty
    /// ConceptHistoryView. Lane C listens for this and routes the user
    /// into ChatView via the existing DailyChallengeView flow.
    static let conceptHistoryStartLearning = Notification.Name("conceptHistoryStartLearning")
}

#Preview {
    NavigationStack {
        ConceptHistoryView(conceptId: "swift-variables")
    }
    .modelContainer(for: [
        UserProfile.self,
        DailyStreak.self,
        ConceptProgress.self,
        StudySession.self,
        ChatMessage.self
    ], inMemory: true)
}
