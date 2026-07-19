import Combine
import Foundation

// Local-only habit stats (PRD P1-3). JSON in Application Support, atomic writes,
// last 365 days kept. No network anywhere.

struct DayRecord: Codable, Equatable {
    var date: String // "yyyy-MM-dd" in the local calendar
    var promptedCount: Int = 0
    var completedCount: Int = 0
    var skippedCount: Int = 0
    var snoozeCount: Int = 0

    /// Adherence = completed ÷ (completed + skipped). Cycles dropped by idle
    /// increment promptedCount but neither completed nor skipped, so they are
    /// excluded from the ratio — honest accounting per PRD §8.4.
    var adherence: Double? {
        let decided = completedCount + skippedCount
        guard decided > 0 else { return nil }
        return Double(completedCount) / Double(decided)
    }
}

final class StatsStore: ObservableObject {
    @Published private(set) var days: [DayRecord] = []

    private let fileURL: URL
    private let calendar: Calendar
    private let now: () -> Date

    private static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init(directory: URL = AppSupport.directory(),
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init) {
        self.fileURL = directory.appendingPathComponent("stats.json")
        self.calendar = calendar
        self.now = now
        self.days = Self.load(from: fileURL)
        prune()
    }

    // MARK: - Recording

    func recordPrompted() { mutateToday { $0.promptedCount += 1 } }
    func recordCompleted() { mutateToday { $0.completedCount += 1 } }
    func recordSkipped() { mutateToday { $0.skippedCount += 1 } }
    func recordSnoozed() { mutateToday { $0.snoozeCount += 1 } }

    // MARK: - Queries

    static func dayKey(for date: Date) -> String {
        dayFormat.string(from: date)
    }

    var todayRecord: DayRecord {
        let key = Self.dayKey(for: now())
        return days.first(where: { $0.date == key }) ?? DayRecord(date: key)
    }

    var currentStreak: Int {
        Self.streak(records: days, today: now(), calendar: calendar)
    }

    /// Last `count` calendar days ending today, oldest first, with empty
    /// records filled in for days without data (for the 14-day bar list).
    func recentDays(_ count: Int) -> [DayRecord] {
        let byKey = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
        var result: [DayRecord] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now()) else { continue }
            let key = Self.dayKey(for: day)
            result.append(byKey[key] ?? DayRecord(date: key))
        }
        return result
    }

    /// Streak = consecutive days ending today (or earlier, since neutral days
    /// don't break it) with adherence ≥ 80% and ≥ 3 prompted breaks.
    /// Days with < 3 prompted breaks are neutral: they neither break nor
    /// extend the streak (PRD P1-3 / US-10).
    static func streak(records: [DayRecord], today: Date, calendar: Calendar) -> Int {
        let byKey = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0) })
        var streak = 0
        var day = today
        for _ in 0..<366 {
            let key = dayKey(for: day)
            if let record = byKey[key], record.promptedCount >= 3 {
                // A day with ≥3 prompts where every cycle was dropped by idle
                // has no adherence ratio; treat it as neutral, not a break.
                if let adherence = record.adherence {
                    if adherence >= 0.8 {
                        streak += 1
                    } else {
                        break
                    }
                }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // MARK: - Persistence

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(days)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("EyeBreak: failed to save stats (\(error))\n".utf8))
        }
    }

    // MARK: - Private

    private static func load(from url: URL) -> [DayRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode([DayRecord].self, from: data)
        } catch {
            FileHandle.standardError.write(Data("EyeBreak: stats.json unreadable, starting fresh (\(error))\n".utf8))
            return []
        }
    }

    private func mutateToday(_ change: (inout DayRecord) -> Void) {
        let key = Self.dayKey(for: now())
        if let index = days.firstIndex(where: { $0.date == key }) {
            change(&days[index])
        } else {
            var record = DayRecord(date: key)
            change(&record)
            days.append(record)
        }
        prune()
        save()
    }

    private func prune() {
        guard let cutoffDate = calendar.date(byAdding: .day, value: -365, to: now()) else { return }
        let cutoff = Self.dayKey(for: cutoffDate)
        // "yyyy-MM-dd" sorts lexicographically in date order.
        days = days.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }
}
