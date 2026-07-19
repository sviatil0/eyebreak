import SwiftUI

// Comfort-habit framing only (PRD P1-3): no goals, no red for "bad" days,
// no medical language. Issue #3: a calm text list — no charts, no tiles.
struct StatsView: View {
    @ObservedObject var store: StatsStore

    var body: some View {
        let today = store.todayRecord
        let adherencePercent = today.adherence.map { Int(($0 * 100).rounded()) }

        VStack(alignment: .leading, spacing: 16) {
            Text(CopyStrings.statsTitle)
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 0) {
                statRow(String(format: CopyStrings.statsToday, today.completedCount, today.skippedCount))
                if let adherencePercent {
                    Divider()
                    statRow(String(format: CopyStrings.statsAdherence, adherencePercent), numeralRuns: 1)
                }
                Divider()
                statRow(
                    String(format: CopyStrings.statsStreak, store.currentStreak),
                    numeralRuns: 1,
                    showsAccentDot: true
                )
            }

            Text(CopyStrings.statsFootnote)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 380, alignment: .leading)
    }

    // One calm row per existing stat string; the stat numerals inside the
    // sentence are emphasized (rounded, semibold) without changing the text.
    private func statRow(_ line: String, numeralRuns: Int = .max, showsAccentDot: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if showsAccentDot {
                Circle()
                    .fill(Color.duskBlue)
                    .frame(width: 6, height: 6)
            }
            numeralStyled(line, maxRuns: numeralRuns)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
    }

    // Renders `line` verbatim, styling up to `maxRuns` numeral runs
    // (digits plus an immediately following "%") at display size.
    private func numeralStyled(_ line: String, maxRuns: Int) -> Text {
        let numeralFont = Font.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit()
        var out = Text(verbatim: "")
        var styledRuns = 0
        var i = line.startIndex
        while i < line.endIndex {
            if line[i].isNumber, styledRuns < maxRuns {
                var j = line.index(after: i)
                while j < line.endIndex, line[j].isNumber { j = line.index(after: j) }
                if j < line.endIndex, line[j] == "%" { j = line.index(after: j) }
                out = out + Text(verbatim: String(line[i..<j])).font(numeralFont)
                styledRuns += 1
                i = j
            } else {
                var j = line.index(after: i)
                while j < line.endIndex, !(line[j].isNumber && styledRuns < maxRuns) {
                    j = line.index(after: j)
                }
                out = out + Text(verbatim: String(line[i..<j]))
                i = j
            }
        }
        return out.font(.system(size: 13))
    }
}
