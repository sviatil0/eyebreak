// Pure state machine for the 20-20-20 break cycle (PRD §8.4).
//
// No Foundation timers, no AppKit. Time is injected as monotonic seconds
// (mach uptime, which pauses during system sleep — sleep is handled
// explicitly via the `systemWoke` event, so wall-clock changes can never
// fire or starve a break).

struct BreakScheduler: Equatable {
    typealias Seconds = Double

    struct Config: Equatable {
        var workInterval: Seconds
        var breakDuration: Seconds
        var snoozeDuration: Seconds
        var idleThreshold: Seconds
        var gracePeriod: Seconds = 2
        var quietRecheckInterval: Seconds = 30

        static let standard = Config(
            workInterval: 1200, breakDuration: 20,
            snoozeDuration: 180, idleThreshold: 300
        )
    }

    enum State: Equatable {
        /// Counting down to the next prompt. `deferred` means the break is
        /// already due but quiet checks are holding it (status: "waiting").
        case working(deadline: Seconds, deferred: Bool)
        /// Overlay fading in; clicks/keys other than the buttons do nothing.
        case prompting(graceDeadline: Seconds)
        case onBreak(deadline: Seconds)
        case snoozed(deadline: Seconds, deferred: Bool)
        /// Manual quiet mode. `until == nil` means "until re-enabled".
        case paused(until: Seconds?)
        case idle
    }

    enum Event: Equatable {
        case timerFired
        case breakCompleted
        case snoozed
        case skipped
        case paused(until: Seconds?)
        case resumed
        case idleDetected
        case activityResumed
        case graceElapsed
        case quietCheckPassed
        case quietCheckFailed
        case takeBreakNow
        case settingsChanged(Config)
        case systemWoke(sleepDuration: Seconds)
    }

    enum Effect: Equatable {
        /// Fade the overlay in; the driver sends `.graceElapsed` at the grace deadline.
        case showOverlay
        case hideOverlay
        /// Show the completion line briefly, then fade the overlay out.
        case showCompletionThenHide
        case startBreakCountdown
        case recordPrompted
        case recordCompleted
        case recordSkipped
        case recordSnoozed
        /// Driver runs the quiet checks and feeds back
        /// `.quietCheckPassed` or `.quietCheckFailed`.
        case checkQuiet
    }

    private(set) var state: State
    private(set) var config: Config

    /// True once the overlay has shown for the current break cycle, so a
    /// snoozed-and-reshown break is counted as prompted exactly once (PRD §8.4
    /// accounting rules).
    private var promptedThisCycle = false

    init(config: Config, now: Seconds, startPaused: Bool = false) {
        self.config = config
        self.state = startPaused
            ? .paused(until: nil)
            : .working(deadline: now + config.workInterval, deferred: false)
    }

    /// The next moment the driver must deliver a timer event, if any.
    /// The driver maps the state to the right event at fire time:
    /// working/snoozed → timerFired, prompting → graceElapsed,
    /// onBreak → breakCompleted, paused(until:) → timerFired.
    var nextDeadline: Seconds? {
        switch state {
        case .working(let d, let deferred): return deferred ? nil : d
        case .prompting(let g): return g
        case .onBreak(let d): return d
        case .snoozed(let d, let deferred): return deferred ? nil : d
        case .paused(let until): return until
        case .idle: return nil
        }
    }

    /// True while quiet checks are holding a due break (drives the 30 s recheck).
    var isDeferred: Bool {
        switch state {
        case .working(_, true), .snoozed(_, true): return true
        default: return false
        }
    }

    var isOverlayVisible: Bool {
        switch state {
        case .prompting, .onBreak: return true
        default: return false
        }
    }

    mutating func handle(_ event: Event, now: Seconds) -> [Effect] {
        switch event {
        case .timerFired:
            return handleTimerFired(now: now)
        case .quietCheckPassed:
            switch state {
            case .working(_, true), .snoozed(_, true):
                return beginPrompt(now: now)
            default:
                return []
            }
        case .quietCheckFailed:
            // Stay deferred; the driver schedules the next 30 s recheck.
            return []
        case .graceElapsed:
            guard case .prompting = state else { return [] }
            state = .onBreak(deadline: now + config.breakDuration)
            return [.startBreakCountdown]
        case .breakCompleted:
            guard case .onBreak = state else { return [] }
            promptedThisCycle = false
            state = .working(deadline: now + config.workInterval, deferred: false)
            return [.showCompletionThenHide, .recordCompleted]
        case .snoozed:
            switch state {
            case .prompting, .onBreak:
                state = .snoozed(deadline: now + config.snoozeDuration, deferred: false)
                return [.hideOverlay, .recordSnoozed]
            default:
                return []
            }
        case .skipped:
            switch state {
            case .prompting, .onBreak:
                promptedThisCycle = false
                state = .working(deadline: now + config.workInterval, deferred: false)
                return [.hideOverlay, .recordSkipped]
            default:
                return []
            }
        case .paused(let until):
            switch state {
            case .prompting, .onBreak:
                // Pausing mid-overlay dismisses it and records a skip (PRD P1-1).
                promptedThisCycle = false
                state = .paused(until: until)
                return [.hideOverlay, .recordSkipped]
            case .working, .snoozed, .idle:
                promptedThisCycle = false
                state = .paused(until: until)
                return []
            case .paused:
                state = .paused(until: until)
                return []
            }
        case .resumed:
            guard case .paused = state else { return [] }
            state = .working(deadline: now + config.workInterval, deferred: false)
            return []
        case .idleDetected:
            switch state {
            case .working, .snoozed:
                // Pending break (if any) is dropped: neither completed nor skipped.
                promptedThisCycle = false
                state = .idle
                return []
            case .prompting, .onBreak:
                // Idle during a break is expected — looking away is the point.
                return []
            case .paused, .idle:
                return []
            }
        case .activityResumed:
            guard case .idle = state else { return [] }
            state = .working(deadline: now + config.workInterval, deferred: false)
            return []
        case .takeBreakNow:
            switch state {
            case .working, .snoozed, .idle:
                // Bypasses quiet checks — explicit user intent (PRD §8.4).
                return beginPrompt(now: now)
            case .prompting, .onBreak, .paused:
                return []
            }
        case .settingsChanged(let newConfig):
            config = newConfig
            clampDeadlines(now: now)
            return []
        case .systemWoke(let sleepDuration):
            guard sleepDuration > config.idleThreshold else { return [] }
            switch state {
            case .paused:
                return [] // "any non-paused" — a paused app stays paused.
            case .prompting, .onBreak:
                promptedThisCycle = false
                state = .working(deadline: now + config.workInterval, deferred: false)
                return [.hideOverlay]
            case .working, .snoozed, .idle:
                promptedThisCycle = false
                state = .working(deadline: now + config.workInterval, deferred: false)
                return []
            }
        }
    }

    // MARK: - Private

    private mutating func handleTimerFired(now: Seconds) -> [Effect] {
        switch state {
        case .working(let d, false):
            // Break is due: mark deferred while the quiet check runs. The
            // driver answers synchronously, so the "waiting" state is only
            // user-visible when the check actually fails.
            state = .working(deadline: d, deferred: true)
            return [.checkQuiet]
        case .snoozed(let d, false):
            state = .snoozed(deadline: d, deferred: true)
            return [.checkQuiet]
        case .paused(let until):
            guard let until, until <= now else { return [] }
            state = .working(deadline: now + config.workInterval, deferred: false)
            return []
        default:
            return []
        }
    }

    private mutating func beginPrompt(now: Seconds) -> [Effect] {
        var effects: [Effect] = [.showOverlay]
        if !promptedThisCycle {
            promptedThisCycle = true
            effects.append(.recordPrompted)
        }
        state = .prompting(graceDeadline: now + config.gracePeriod)
        return effects
    }

    private mutating func clampDeadlines(now: Seconds) {
        // If the current deadline exceeds the new interval length,
        // clamp to now + new interval (PRD §8.4 transition table).
        switch state {
        case .working(let d, let deferred):
            state = .working(deadline: min(d, now + config.workInterval), deferred: deferred)
        case .snoozed(let d, let deferred):
            state = .snoozed(deadline: min(d, now + config.snoozeDuration), deferred: deferred)
        case .onBreak(let d):
            state = .onBreak(deadline: min(d, now + config.breakDuration))
        case .prompting, .paused, .idle:
            break
        }
    }
}
