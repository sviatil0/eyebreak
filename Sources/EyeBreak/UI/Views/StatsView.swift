import SwiftUI

// Comfort-habit framing only (PRD P1-3): no goals, no red for "bad" days,
// no medical language.
struct StatsView: View {
    @ObservedObject var store: StatsStore

    var body: some View {
        let today = store.todayRecord
        let adherencePercent = today.adherence.map { Int(($0 * 100).rounded()) }

        VStack(alignment: .leading, spacing: 14) {
            Text(CopyStrings.statsTitle)
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: CopyStrings.statsToday, today.completedCount, today.skippedCount))
                if let adherencePercent {
                    Text(String(format: CopyStrings.statsAdherence, adherencePercent))
                }
                Text(String(format: CopyStrings.statsStreak, store.currentStreak))
            }
            .font(.body)

            Divider()

            Text("Last 14 days")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(store.recentDays(14), id: \.date) { day in
                    dayRow(day)
                }
            }

            Text(CopyStrings.statsFootnote)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 6)
        }
        .padding(20)
        .frame(width: 360)
    }

    private func dayRow(_ day: DayRecord) -> some View {
        let maxBar = 12
        let completed = min(day.completedCount, maxBar)
        return HStack(spacing: 8) {
            Text(shortLabel(day.date))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(completed) / CGFloat(maxBar))
                }
            }
            .frame(height: 8)
            Text("\(day.completedCount)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 22, alignment: .trailing)
        }
        .frame(height: 14)
    }

    private func shortLabel(_ date: String) -> String {
        // "yyyy-MM-dd" → "MM-dd"
        String(date.suffix(5))
    }
}
