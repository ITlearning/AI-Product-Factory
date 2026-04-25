import SwiftUI
import SwiftData

/// Read-only conversation viewer for one StudySession. Pushed from
/// `ConceptHistoryView` when the user taps a session row. Reuses
/// `MessageBubble` so visual presentation matches the live ChatView,
/// minus the input bar and any actions.
struct SessionConversationView: View {
    let session: StudySession

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(orderedMessages) { ui in
                    MessageBubble(message: ui)
                        .id(ui.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(session.conceptTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Derived

    /// Sorts the persisted ChatMessage models by `orderIndex` (stable),
    /// falling back to `createdAt` for ties, then maps to `ChatMessageUI`
    /// for `MessageBubble` rendering. `isStreaming` is always false for
    /// historical sessions.
    private var orderedMessages: [ChatMessageUI] {
        let sorted = session.messages.sorted { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex {
                return lhs.orderIndex < rhs.orderIndex
            }
            return lhs.createdAt < rhs.createdAt
        }

        return sorted.map { message in
            ChatMessageUI(
                role: message.messageRole,
                content: message.content,
                isStreaming: false
            )
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.startedAt)
    }
}
