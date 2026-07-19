import Foundation

// Optional extra nudges (PRD P1-4). Each type is individually toggleable.
// Banners respect quiet mode and idle exactly like main breaks: a reminder
// that comes due while suppressed is dropped, never queued.
final class SecondaryReminders {
    /// Snapshot of scheduler-side conditions, provided by the AppDelegate.
    struct Context {
        /// True only during a plain working/snoozed countdown — not on break,
        /// not quiet-deferred, not paused, not idle.
        var canShowBanner: Bool
        /// True while the user is actively at the machine and un-paused
        /// (drives the "active screen time" accumulators).
        var accumulatesActiveTime: Bool
        var secondsToNextBreak: Double?
        var secondsSinceLastBreakEnd: Double?
    }

    var settingsProvider: () -> Settings = { Settings() }
    var contextProvider: () -> Context = { Context(canShowBanner: false, accumulatesActiveTime: false, secondsToNextBreak: nil, secondsSinceLastBreakEnd: nil) }
    var showBanner: ((String) -> Void)?

    private var timer: DispatchSourceTimer?
    private let tickInterval: Double = 30

    private var blinkActiveSeconds: Double = 0
    private var tearsActiveSeconds: Double = 0
    /// Daily reminders resolved per local day ("fired" or "dropped"), so a
    /// suppressed reminder is not re-attempted later the same day (no queuing).
    private var dailyResolved: [String: String] = [:]

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + tickInterval, repeating: tickInterval, leeway: .seconds(5))
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let settings = settingsProvider()
        let context = contextProvider()

        if context.accumulatesActiveTime {
            blinkActiveSeconds += tickInterval
            tearsActiveSeconds += tickInterval
        }

        // Blink: every N min of active time, held (not dropped) when close to
        // a main break so it "never fires within 3 min of a break".
        if settings.blinkReminderOn {
            if blinkActiveSeconds >= Double(settings.blinkIntervalSec) {
                if !context.canShowBanner {
                    blinkActiveSeconds = 0 // suppressed state → dropped
                } else if breakProximityOK(context) {
                    showBanner?(CopyStrings.bannerBlink)
                    blinkActiveSeconds = 0
                }
            }
        } else {
            blinkActiveSeconds = 0
        }

        // Artificial tears: every 1–4 h of active time.
        if settings.tearsReminderOn {
            if tearsActiveSeconds >= Double(settings.tearsIntervalSec) {
                if !context.canShowBanner {
                    tearsActiveSeconds = 0
                } else if breakProximityOK(context) {
                    showBanner?(CopyStrings.bannerTears)
                    tearsActiveSeconds = 0
                }
            }
        } else {
            tearsActiveSeconds = 0
        }

        // Daily reminders at a set local time.
        if settings.warmCompressOn {
            fireDaily(key: "compress", at: settings.warmCompressTime, context: context) {
                CopyStrings.bannerCompress
            }
        }
        if settings.environmentRemindersOn {
            fireDaily(key: "environment", at: settings.environmentTime, context: context) {
                // Alternate glare/airflow by day parity — stateless across restarts.
                let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
                return dayOfYear % 2 == 0 ? CopyStrings.bannerGlare : CopyStrings.bannerAirflow
            }
        }
    }

    private func breakProximityOK(_ context: Context) -> Bool {
        if let toNext = context.secondsToNextBreak, toNext < 180 { return false }
        if let sinceLast = context.secondsSinceLastBreakEnd, sinceLast < 180 { return false }
        return true
    }

    private func fireDaily(key: String, at hhmm: String, context: Context, text: () -> String) {
        let today = StatsStore.dayKey(for: Date())
        guard dailyResolved[key] != today,
              let pastTarget = minutesPastTarget(hhmm), pastTarget >= 0
        else { return }
        // Resolve exactly once per day: shown if conditions allow, otherwise
        // dropped for today (PRD P1-4: dropped, not queued). A launch hours
        // after the target time (fired-state is in-memory only) also resolves
        // silently rather than reminding at an odd hour.
        dailyResolved[key] = today
        if pastTarget < 60, context.canShowBanner, breakProximityOK(context) {
            showBanner?(text())
        }
    }

    private func minutesPastTarget(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nowMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return nowMinutes - (parts[0] * 60 + parts[1])
    }
}
