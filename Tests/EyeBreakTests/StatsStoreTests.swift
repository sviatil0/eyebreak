import Foundation
import Testing
@testable import EyeBreak

// Adherence + streak math and JSON persistence (PRD P1-3).
// Swift Testing (not XCTest) so `swift test` works with Command Line Tools only.
@Suite struct StatsStoreTests {
    var calendar: Calendar { Calendar.current }

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func day(_ y: Int, _ m: Int, _ d: Int,
             prompted: Int, completed: Int, skipped: Int) -> DayRecord {
        DayRecord(
            date: StatsStore.dayKey(for: date(y, m, d)),
            promptedCount: prompted,
            completedCount: completed,
            skippedCount: skipped,
            snoozeCount: 0
        )
    }

    // MARK: - Adherence

    @Test func adherenceIsCompletedOverDecided() {
        let record = day(2026, 7, 19, prompted: 10, completed: 8, skipped: 2)
        #expect(abs(record.adherence! - 0.8) < 0.0001)
    }

    @Test func idleDroppedCyclesExcludedFromAdherence() {
        // 10 prompted, 4 completed, 1 skipped, 5 dropped by idle:
        // adherence = 4 / (4 + 1), not 4 / 10.
        let record = day(2026, 7, 19, prompted: 10, completed: 4, skipped: 1)
        #expect(abs(record.adherence! - 0.8) < 0.0001)
    }

    @Test func adherenceNilWhenNothingDecided() {
        let record = day(2026, 7, 19, prompted: 2, completed: 0, skipped: 0)
        #expect(record.adherence == nil)
    }

    // MARK: - Streak

    @Test func streakCountsConsecutiveQualifyingDays() {
        let records = [
            day(2026, 7, 17, prompted: 10, completed: 9, skipped: 1),
            day(2026, 7, 18, prompted: 8, completed: 7, skipped: 1),
            day(2026, 7, 19, prompted: 5, completed: 5, skipped: 0),
        ]
        #expect(StatsStore.streak(records: records, today: date(2026, 7, 19), calendar: calendar) == 3)
    }

    @Test func streakBrokenByBadDay() {
        let records = [
            day(2026, 7, 17, prompted: 10, completed: 10, skipped: 0),
            day(2026, 7, 18, prompted: 10, completed: 2, skipped: 8), // 20% — breaks it
            day(2026, 7, 19, prompted: 5, completed: 5, skipped: 0),
        ]
        #expect(StatsStore.streak(records: records, today: date(2026, 7, 19), calendar: calendar) == 1)
    }

    @Test func daysWithFewerThanThreePromptsAreNeutral() {
        let records = [
            day(2026, 7, 16, prompted: 10, completed: 9, skipped: 1),
            day(2026, 7, 17, prompted: 2, completed: 0, skipped: 2), // <3 prompted: neutral
            day(2026, 7, 18, prompted: 8, completed: 8, skipped: 0),
            day(2026, 7, 19, prompted: 5, completed: 5, skipped: 0),
        ]
        // Neutral day neither breaks nor extends: 16th + 18th + 19th = 3.
        #expect(StatsStore.streak(records: records, today: date(2026, 7, 19), calendar: calendar) == 3)
    }

    @Test func todayWithFewPromptsFallsBackToYesterday() {
        let records = [
            day(2026, 7, 17, prompted: 10, completed: 9, skipped: 1),
            day(2026, 7, 18, prompted: 8, completed: 7, skipped: 1),
            day(2026, 7, 19, prompted: 1, completed: 1, skipped: 0), // today, <3 prompted
        ]
        #expect(StatsStore.streak(records: records, today: date(2026, 7, 19), calendar: calendar) == 2)
    }

    @Test func missingDaysAreNeutralGaps() {
        let records = [
            day(2026, 7, 10, prompted: 6, completed: 6, skipped: 0),
            // 11th–18th missing entirely (e.g. vacation)
            day(2026, 7, 19, prompted: 5, completed: 5, skipped: 0),
        ]
        #expect(StatsStore.streak(records: records, today: date(2026, 7, 19), calendar: calendar) == 2)
    }

    @Test func zeroStreakWhenTodayIsBad() {
        let records = [
            day(2026, 7, 19, prompted: 6, completed: 1, skipped: 5),
        ]
        #expect(StatsStore.streak(records: records, today: date(2026, 7, 19), calendar: calendar) == 0)
    }

    @Test func emptyRecordsGiveZeroStreak() {
        #expect(StatsStore.streak(records: [], today: date(2026, 7, 19), calendar: calendar) == 0)
    }

    // MARK: - Store behavior (temp directory; never touches real App Support)

    func makeStore(now: Date) throws -> (StatsStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EyeBreakTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (StatsStore(directory: dir, now: { now }), dir)
    }

    @Test func recordingAccumulatesIntoToday() throws {
        let today = date(2026, 7, 19)
        let (store, dir) = try makeStore(now: today)
        defer { try? FileManager.default.removeItem(at: dir) }

        store.recordPrompted()
        store.recordCompleted()
        store.recordPrompted()
        store.recordSkipped()
        store.recordSnoozed()

        let record = store.todayRecord
        #expect(record.promptedCount == 2)
        #expect(record.completedCount == 1)
        #expect(record.skippedCount == 1)
        #expect(record.snoozeCount == 1)
    }

    @Test func persistenceRoundTrip() throws {
        let today = date(2026, 7, 19)
        let (store, dir) = try makeStore(now: today)
        defer { try? FileManager.default.removeItem(at: dir) }

        store.recordPrompted()
        store.recordCompleted()
        store.save()

        let reloaded = StatsStore(directory: dir, now: { today })
        #expect(reloaded.todayRecord.completedCount == 1)
        #expect(reloaded.todayRecord.promptedCount == 1)
    }

    @Test func corruptStatsFileStartsFreshWithoutCrashing() throws {
        let today = date(2026, 7, 19)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EyeBreakTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("not json{{".utf8).write(to: dir.appendingPathComponent("stats.json"))

        let store = StatsStore(directory: dir, now: { today })
        #expect(store.days == [])
    }

    @Test func pruneKeepsOnlyLast365Days() throws {
        let today = date(2026, 7, 19)
        let (_, dir) = try makeStore(now: today)
        defer { try? FileManager.default.removeItem(at: dir) }

        let old = DayRecord(
            date: "2024-01-01", promptedCount: 5,
            completedCount: 5, skippedCount: 0, snoozeCount: 0
        )
        try JSONEncoder().encode([old]).write(to: dir.appendingPathComponent("stats.json"))

        let reloaded = StatsStore(directory: dir, now: { today })
        reloaded.recordPrompted()
        #expect(!reloaded.days.contains(where: { $0.date == "2024-01-01" }))
        #expect(reloaded.days.count == 1)
    }

    @Test func recentDaysFillsGapsOldestFirst() throws {
        let today = date(2026, 7, 19)
        let (store, dir) = try makeStore(now: today)
        defer { try? FileManager.default.removeItem(at: dir) }

        store.recordCompleted()
        let recent = store.recentDays(14)
        #expect(recent.count == 14)
        #expect(recent.last?.date == StatsStore.dayKey(for: today))
        #expect(recent.last?.completedCount == 1)
        #expect(recent.first?.completedCount == 0)
    }
}
