import SwiftUI

struct CalendarHeatmapView: View {
    let studyData: [Date: ProgressViewModel.StudyDay]

    private let weeksToShow = 15
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3
    private let calendar = Calendar.current
    private let dayLabels = ["일", "월", "화", "수", "목", "금", "토"]

    // MARK: - Computed dates

    private var today: Date {
        calendar.startOfDay(for: .now)
    }

    /// Grid of dates organised as [column(week)][row(weekday)].
    /// Column 0 is the oldest week, last column contains today.
    private var weeks: [[Date?]] {
        // End of grid = Saturday of the current week (or today's week)
        let todayWeekday = calendar.component(.weekday, from: today) // 1=Sun … 7=Sat
        let daysUntilSaturday = 7 - todayWeekday
        let gridEnd = calendar.date(byAdding: .day, value: daysUntilSaturday, to: today)!
        let totalDays = weeksToShow * 7
        let gridStart = calendar.date(byAdding: .day, value: -(totalDays - 1), to: gridEnd)!

        var result: [[Date?]] = []
        var current = gridStart

        for _ in 0..<weeksToShow {
            var week: [Date?] = []
            for _ in 0..<7 {
                if current > today {
                    week.append(nil) // future dates
                } else {
                    week.append(current)
                }
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            }
            result.append(week)
        }
        return result
    }

    /// Month labels with their column positions.
    private var monthLabels: [(String, Int)] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월"

        var labels: [(String, Int)] = []
        var lastMonth = -1

        for (colIndex, week) in weeks.enumerated() {
            // Use the first non-nil date in the week (Sunday)
            guard let firstDate = week.first(where: { $0 != nil }) ?? nil else { continue }
            let month = calendar.component(.month, from: firstDate)
            if month != lastMonth {
                labels.append((formatter.string(from: firstDate), colIndex))
                lastMonth = month
            }
        }
        return labels
    }

    // MARK: - Body

    var body: some View {
        let gridWeeks = weeks

        VStack(alignment: .leading, spacing: 2) {
            // Month labels row
            monthRow(weeks: gridWeeks)

            // Main grid: day labels + heatmap cells
            HStack(alignment: .top, spacing: 2) {
                // Day-of-week labels
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { row in
                        if row % 2 == 1 { // Show Mon, Wed, Fri only to save space
                            Text(dayLabels[row])
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 14, height: cellSize)
                        } else {
                            Color.clear
                                .frame(width: 14, height: cellSize)
                        }
                    }
                }

                // Heatmap grid
                HStack(spacing: cellSpacing) {
                    ForEach(0..<gridWeeks.count, id: \.self) { col in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { row in
                                cellView(date: gridWeeks[col][row])
                            }
                        }
                    }
                }
            }

            // Legend
            legendRow
        }
        .padding(.vertical, 4)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func monthRow(weeks: [[Date?]]) -> some View {
        let labels = monthLabels
        HStack(spacing: 0) {
            // Offset for the day label column
            Color.clear
                .frame(width: 16)

            ZStack(alignment: .leading) {
                Color.clear
                    .frame(height: 14)

                ForEach(labels, id: \.1) { label, colIndex in
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .offset(x: CGFloat(colIndex) * (cellSize + cellSpacing))
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(date: Date?) -> some View {
        if let date {
            let isToday = calendar.isDateInToday(date)
            RoundedRectangle(cornerRadius: 2)
                .fill(colorForDay(date))
                .frame(width: cellSize, height: cellSize)
                .overlay {
                    if isToday {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(Color.primary.opacity(0.6), lineWidth: 1)
                    }
                }
        } else {
            // Future date — invisible placeholder
            Color.clear
                .frame(width: cellSize, height: cellSize)
        }
    }

    private var legendRow: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("적음")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(intensity == 0 ? Color(.systemGray6) : Color.green.opacity(0.2 + intensity * 0.6))
                    .frame(width: cellSize, height: cellSize)
            }

            Text("많음")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Color Logic

    private func colorForDay(_ date: Date) -> Color {
        let day = calendar.startOfDay(for: date)
        guard let info = studyData[day] else {
            return Color(.systemGray6)
        }
        if info.hasMastery {
            return Color.green.opacity(0.85)
        }
        // Scale by session count: 1 session = light, 3+ = medium-dark
        let intensity = min(Double(info.sessionCount) / 3.0, 1.0)
        return Color.green.opacity(0.2 + intensity * 0.45)
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    var sampleData: [Date: ProgressViewModel.StudyDay] = [:]

    for dayOffset in stride(from: 0, to: 90, by: 1) {
        if Int.random(in: 0...2) > 0 { continue }
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let count = Int.random(in: 1...4)
        sampleData[date] = ProgressViewModel.StudyDay(
            date: date,
            sessionCount: count,
            hasMastery: count >= 3
        )
    }

    return CalendarHeatmapView(studyData: sampleData)
        .padding()
}
