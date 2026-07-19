import AppKit

// Owns real time for the pure BreakScheduler: schedules DispatchSourceTimers
// for the machine's next deadline, translates UI/monitor callbacks into
// events, and executes effects. Everything runs on the main queue.
final class SchedulerDriver {
    // Injected by AppDelegate (closures avoid retain cycles back into UI).
    var quietCheck: () -> Bool = { false }
    var showOverlay: (() -> Void)?
    var hideOverlay: (() -> Void)?
    var showCompletionThenHide: (() -> Void)?
    var startBreakCountdown: ((Int) -> Void)?
    var onStateChange: (() -> Void)?

    private(set) var scheduler: BreakScheduler
    private let stats: StatsStore

    private var deadlineTimer: DispatchSourceTimer?
    private var quietRecheckTimer: DispatchSourceTimer?
    private var pending: [BreakScheduler.Event] = []
    private var processing = false

    /// Monotonic clock time (seconds) when the last break ended, for the
    /// secondary reminders' "not within 3 min of a break" rule.
    private(set) var lastBreakEnded: Double?

    /// Wall-clock date a timed pause expires (for "Paused until 3:45 PM").
    private(set) var pausedUntilDate: Date?

    init(settings: Settings, stats: StatsStore) {
        self.stats = stats
        scheduler = BreakScheduler(
            config: settings.schedulerConfig,
            now: Self.monotonicNow(),
            startPaused: settings.pauseUntilReenabled
        )
    }

    func start() {
        afterTransition()
    }

    // Mach uptime: monotonic, pauses during system sleep. Sleep is handled
    // explicitly via systemWoke, so wall-clock changes never affect deadlines.
    static func monotonicNow() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }

    // MARK: - Public event entry points

    func takeBreakNow() { feed(.takeBreakNow) }
    func snooze() { feed(.snoozed) }
    func skip() { feed(.skipped) }
    func breakCompleted() { feed(.breakCompleted) }

    func pause(seconds: Double?) {
        pausedUntilDate = seconds.map { Date().addingTimeInterval($0) }
        feed(.paused(until: seconds.map { Self.monotonicNow() + $0 }))
    }

    func resume() {
        pausedUntilDate = nil
        feed(.resumed)
    }

    func idleDetected() { feed(.idleDetected) }
    func activityResumed() { feed(.activityResumed) }
    func systemWoke(sleepDuration: Double) { feed(.systemWoke(sleepDuration: sleepDuration)) }
    func settingsChanged(_ settings: Settings) { feed(.settingsChanged(settings.schedulerConfig)) }

    // MARK: - Derived state for UI / reminders

    var state: BreakScheduler.State { scheduler.state }

    /// Seconds until the next prompt, when counting down.
    var secondsToNextBreak: Double? {
        switch scheduler.state {
        case .working(let d, false), .snoozed(let d, false):
            return max(0, d - Self.monotonicNow())
        default:
            return nil
        }
    }

    /// Banners may show only during a plain working countdown (PRD P1-4).
    var canShowBanner: Bool {
        if case .working(_, false) = scheduler.state { return true }
        if case .snoozed(_, false) = scheduler.state { return true }
        return false
    }

    var secondsSinceLastBreakEnd: Double? {
        lastBreakEnded.map { Self.monotonicNow() - $0 }
    }

    // MARK: - Event loop

    private func feed(_ event: BreakScheduler.Event) {
        pending.append(event)
        guard !processing else { return }
        processing = true
        while !pending.isEmpty {
            let next = pending.removeFirst()
            let effects = scheduler.handle(next, now: Self.monotonicNow())
            effects.forEach(perform)
        }
        processing = false
        afterTransition()
    }

    private func perform(_ effect: BreakScheduler.Effect) {
        switch effect {
        case .showOverlay:
            showOverlay?()
        case .hideOverlay:
            hideOverlay?()
        case .showCompletionThenHide:
            showCompletionThenHide?()
        case .startBreakCountdown:
            startBreakCountdown?(Int(scheduler.config.breakDuration.rounded()))
        case .recordPrompted:
            stats.recordPrompted()
        case .recordCompleted:
            stats.recordCompleted()
            lastBreakEnded = Self.monotonicNow()
        case .recordSkipped:
            stats.recordSkipped()
            lastBreakEnded = Self.monotonicNow()
        case .recordSnoozed:
            stats.recordSnoozed()
        case .checkQuiet:
            // Failure inside the monitor returns false → not quiet → break shows.
            pending.append(quietCheck() ? .quietCheckFailed : .quietCheckPassed)
        }
    }

    private func afterTransition() {
        scheduleDeadlineTimer()
        scheduleQuietRecheckIfNeeded()
        if case .paused = scheduler.state {} else { pausedUntilDate = nil }
        onStateChange?()
    }

    private func scheduleDeadlineTimer() {
        deadlineTimer?.cancel()
        deadlineTimer = nil
        guard let deadline = scheduler.nextDeadline else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        let nanos = UInt64(max(0, deadline) * 1_000_000_000)
        timer.schedule(deadline: DispatchTime(uptimeNanoseconds: nanos), leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in self?.deadlineFired() }
        timer.resume()
        deadlineTimer = timer
    }

    private func deadlineFired() {
        switch scheduler.state {
        case .working, .snoozed, .paused:
            feed(.timerFired)
        case .prompting:
            feed(.graceElapsed)
        case .onBreak:
            feed(.breakCompleted)
        case .idle:
            break
        }
    }

    private func scheduleQuietRecheckIfNeeded() {
        quietRecheckTimer?.cancel()
        quietRecheckTimer = nil
        guard scheduler.isDeferred else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + scheduler.config.quietRecheckInterval, leeway: .seconds(2))
        timer.setEventHandler { [weak self] in
            guard let self, self.scheduler.isDeferred else { return }
            self.feed(self.quietCheck() ? .quietCheckFailed : .quietCheckPassed)
        }
        timer.resume()
        quietRecheckTimer = timer
    }
}
