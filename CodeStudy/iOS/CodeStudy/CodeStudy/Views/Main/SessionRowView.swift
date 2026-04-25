import SwiftUI
import SwiftData

/// One row in the `ConceptHistoryView` session list. Shows date,
/// turn count, duration, and a single-line preview of the first
/// message. The chevron is provided automatically by the surrounding
/// `NavigationLink`.
struct SessionRowView: View {
    let session: StudySession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("📅")
                    .font(.subheadline)

                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text("·")
                    .foregroundStyle(.secondary)

                Text(turnCountText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let duration = formattedDuration {
                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(duration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            if let preview = previewText {
                Text(preview)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Derived

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: session.startedAt)
    }

    private var turnCountText: String {
        let turns = session.turnCount
        let suffix = String(
            localized: "session.row.turns.suffix",
            defaultValue: "회 대화"
        )
        return "\(turns)\(suffix)"
    }

    private var formattedDuration: String? {
        guard let duration = session.duration, duration > 0 else { return nil }
        let minutes = Int(duration / 60)
        if minutes < 1 {
            let seconds = Int(duration)
            let suffix = String(
                localized: "session.row.duration.seconds.suffix",
                defaultValue: "초"
            )
            return "\(seconds)\(suffix)"
        }
        let suffix = String(
            localized: "session.row.duration.minutes.suffix",
            defaultValue: "분"
        )
        return "\(minutes)\(suffix)"
    }

    private var previewText: String? {
        let sorted = session.messages.sorted { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex {
                return lhs.orderIndex < rhs.orderIndex
            }
            return lhs.createdAt < rhs.createdAt
        }
        // First user OR assistant message — whichever came first.
        guard let first = sorted.first(where: { $0.messageRole != .system }) else {
            return nil
        }
        let trimmed = first.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        return trimmed.isEmpty ? nil : "\"\(trimmed)\""
    }

    private var accessibilityDescription: String {
        var parts: [String] = [formattedDate, turnCountText]
        if let duration = formattedDuration {
            parts.append(duration)
        }
        if let preview = previewText {
            parts.append(preview)
        }
        return parts.joined(separator: ", ")
    }
}
