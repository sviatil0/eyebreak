import Foundation
import Testing
@testable import EyeBreak

// Covers the PRD §8.4 transition table with an injected clock.
// Swift Testing (not XCTest) so `swift test` works with Command Line Tools only.
@Suite struct BreakSchedulerTests {
    typealias Event = BreakScheduler.Event
    typealias Effect = BreakScheduler.Effect

    let config = BreakScheduler.Config(
        workInterval: 1200, breakDuration: 20,
        snoozeDuration: 180, idleThreshold: 300
    )

    func makeScheduler(now: Double = 0, startPaused: Bool = false) -> BreakScheduler {
        BreakScheduler(config: config, now: now, startPaused: startPaused)
    }

    /// Drives a scheduler to the prompting state, answering quiet checks "pass".
    func promptedScheduler(now: Double = 1200) -> BreakScheduler {
        var s = makeScheduler(now: 0)
        _ = s.handle(.timerFired, now: now)
        _ = s.handle(.quietCheckPassed, now: now)
        return s
    }

    /// Drives a scheduler to onBreak.
    func onBreakScheduler(now: Double = 1202) -> BreakScheduler {
        var s = promptedScheduler(now: 1200)
        _ = s.handle(.graceElapsed, now: now)
        return s
    }

    // MARK: - Initial state

    @Test func initialStateIsWorkingWithFullInterval() {
        let s = makeScheduler(now: 100)
        #expect(s.state == .working(deadline: 1300, deferred: false))
        #expect(s.nextDeadline == 1300)
    }

    @Test func startPausedUntilReenabled() {
        let s = makeScheduler(now: 0, startPaused: true)
        #expect(s.state == .paused(until: nil))
        #expect(s.nextDeadline == nil)
    }

    // MARK: - working + timerFired

    @Test func timerFiredRequestsQuietCheck() {
        var s = makeScheduler()
        let effects = s.handle(.timerFired, now: 1200)
        #expect(effects == [.checkQuiet])
        #expect(s.isDeferred)
    }

    @Test func quietCheckPassedShowsOverlayAndCountsPromptOnce() {
        var s = makeScheduler()
        _ = s.handle(.timerFired, now: 1200)
        let effects = s.handle(.quietCheckPassed, now: 1200)
        #expect(effects == [.showOverlay, .recordPrompted])
        #expect(s.state == .prompting(graceDeadline: 1202))
    }

    @Test func quietCheckFailedStaysDeferredWithNoDeadline() {
        var s = makeScheduler()
        _ = s.handle(.timerFired, now: 1200)
        let effects = s.handle(.quietCheckFailed, now: 1200)
        #expect(effects == [])
        #expect(s.isDeferred)
        #expect(s.nextDeadline == nil) // driver runs the 30 s recheck instead
    }

    @Test func deferredThenQuietClearsPrompts() {
        var s = makeScheduler()
        _ = s.handle(.timerFired, now: 1200)
        _ = s.handle(.quietCheckFailed, now: 1200)
        let effects = s.handle(.quietCheckPassed, now: 1260)
        #expect(effects == [.showOverlay, .recordPrompted])
        #expect(s.state == .prompting(graceDeadline: 1262))
    }

    @Test func spuriousQuietCheckEventsIgnoredWhileCountingDown() {
        var s = makeScheduler()
        #expect(s.handle(.quietCheckPassed, now: 100) == [])
        #expect(s.handle(.quietCheckFailed, now: 100) == [])
        #expect(s.state == .working(deadline: 1200, deferred: false))
    }

    // MARK: - Grace → break → completion

    @Test func graceElapsedStartsBreakCountdown() {
        var s = promptedScheduler(now: 1200)
        let effects = s.handle(.graceElapsed, now: 1202)
        #expect(effects == [.startBreakCountdown])
        #expect(s.state == .onBreak(deadline: 1222))
    }

    @Test func breakCompletedRestartsFullIntervalAndRecordsCompleted() {
        var s = onBreakScheduler(now: 1202)
        let effects = s.handle(.breakCompleted, now: 1222)
        #expect(effects == [.showCompletionThenHide, .recordCompleted])
        #expect(s.state == .working(deadline: 1222 + 1200, deferred: false))
    }

    // MARK: - Snooze

    @Test func snoozeFromBreakHidesOverlayAndSchedulesSnooze() {
        var s = onBreakScheduler(now: 1202)
        let effects = s.handle(.snoozed, now: 1210)
        #expect(effects == [.hideOverlay, .recordSnoozed])
        #expect(s.state == .snoozed(deadline: 1210 + 180, deferred: false))
    }

    @Test func snoozeFromPromptingAlsoWorks() {
        var s = promptedScheduler(now: 1200)
        let effects = s.handle(.snoozed, now: 1201)
        #expect(effects == [.hideOverlay, .recordSnoozed])
        #expect(s.state == .snoozed(deadline: 1381, deferred: false))
    }

    @Test func repromptAfterSnoozeDoesNotCountPromptedAgain() {
        var s = onBreakScheduler(now: 1202)
        _ = s.handle(.snoozed, now: 1210)
        _ = s.handle(.timerFired, now: 1390)
        let effects = s.handle(.quietCheckPassed, now: 1390)
        // showOverlay but no second recordPrompted: once per break cycle.
        #expect(effects == [.showOverlay])
        #expect(s.state == .prompting(graceDeadline: 1392))
    }

    @Test func snoozedBreakLaterCompletedCountsCompleted() {
        var s = onBreakScheduler(now: 1202)
        _ = s.handle(.snoozed, now: 1210)
        _ = s.handle(.timerFired, now: 1390)
        _ = s.handle(.quietCheckPassed, now: 1390)
        _ = s.handle(.graceElapsed, now: 1392)
        let effects = s.handle(.breakCompleted, now: 1412)
        #expect(effects == [.showCompletionThenHide, .recordCompleted])
    }

    // MARK: - Skip

    @Test func skipFromBreakRestartsFullIntervalAndRecordsSkip() {
        var s = onBreakScheduler(now: 1202)
        let effects = s.handle(.skipped, now: 1205)
        #expect(effects == [.hideOverlay, .recordSkipped])
        #expect(s.state == .working(deadline: 1205 + 1200, deferred: false))
    }

    @Test func skipFromPrompting() {
        var s = promptedScheduler(now: 1200)
        let effects = s.handle(.skipped, now: 1201)
        #expect(effects == [.hideOverlay, .recordSkipped])
        #expect(s.state == .working(deadline: 2401, deferred: false))
    }

    @Test func nextCycleAfterSkipCountsPromptedAgain() {
        var s = onBreakScheduler(now: 1202)
        _ = s.handle(.skipped, now: 1205)
        _ = s.handle(.timerFired, now: 2405)
        let effects = s.handle(.quietCheckPassed, now: 2405)
        #expect(effects == [.showOverlay, .recordPrompted])
    }

    // MARK: - Pause / resume

    @Test func pauseWhileWorking() {
        var s = makeScheduler()
        let effects = s.handle(.paused(until: 1800), now: 600)
        #expect(effects == [])
        #expect(s.state == .paused(until: 1800))
        #expect(s.nextDeadline == 1800)
    }

    @Test func pauseDuringOverlayDismissesAndRecordsSkip() {
        var s = onBreakScheduler(now: 1202)
        let effects = s.handle(.paused(until: nil), now: 1210)
        #expect(effects == [.hideOverlay, .recordSkipped])
        #expect(s.state == .paused(until: nil))
        #expect(s.nextDeadline == nil)
    }

    @Test func timedPauseExpiryResumesWithFreshInterval() {
        var s = makeScheduler()
        _ = s.handle(.paused(until: 1800), now: 600)
        _ = s.handle(.timerFired, now: 1800)
        #expect(s.state == .working(deadline: 1800 + 1200, deferred: false))
    }

    @Test func manualResumeStartsFreshInterval() {
        var s = makeScheduler()
        _ = s.handle(.paused(until: nil), now: 600)
        _ = s.handle(.resumed, now: 900)
        #expect(s.state == .working(deadline: 900 + 1200, deferred: false))
    }

    @Test func idleAndActivityAreNoOpsWhilePaused() {
        var s = makeScheduler()
        _ = s.handle(.paused(until: nil), now: 600)
        #expect(s.handle(.idleDetected, now: 1000) == [])
        #expect(s.state == .paused(until: nil))
        #expect(s.handle(.activityResumed, now: 1100) == [])
        #expect(s.state == .paused(until: nil))
    }

    // MARK: - Idle

    @Test func idleDetectedWhileWorkingResetsToIdle() {
        var s = makeScheduler()
        let effects = s.handle(.idleDetected, now: 700)
        #expect(effects == [])
        #expect(s.state == .idle)
        #expect(s.nextDeadline == nil)
    }

    @Test func activityResumedStartsFreshInterval() {
        var s = makeScheduler()
        _ = s.handle(.idleDetected, now: 700)
        _ = s.handle(.activityResumed, now: 5000)
        #expect(s.state == .working(deadline: 5000 + 1200, deferred: false))
    }

    @Test func idleDuringBreakIsNoOp() {
        var s = onBreakScheduler(now: 1202)
        let effects = s.handle(.idleDetected, now: 1210)
        #expect(effects == [])
        #expect(s.state == .onBreak(deadline: 1222))
    }

    @Test func idleDropsSnoozedPendingBreakWithoutRecording() {
        var s = onBreakScheduler(now: 1202)
        _ = s.handle(.snoozed, now: 1210)
        let effects = s.handle(.idleDetected, now: 1300)
        #expect(effects == []) // dropped: neither completed nor skipped
        #expect(s.state == .idle)
        // Next cycle counts prompted again (previous cycle ended by idle-drop).
        _ = s.handle(.activityResumed, now: 2000)
        _ = s.handle(.timerFired, now: 3200)
        #expect(s.handle(.quietCheckPassed, now: 3200) == [.showOverlay, .recordPrompted])
    }

    @Test func idleWhileDeferredDropsPendingBreak() {
        var s = makeScheduler()
        _ = s.handle(.timerFired, now: 1200)
        _ = s.handle(.quietCheckFailed, now: 1200)
        _ = s.handle(.idleDetected, now: 1300)
        #expect(s.state == .idle)
    }

    // MARK: - Take a break now

    @Test func takeBreakNowPromptsImmediatelyBypassingQuietChecks() {
        var s = makeScheduler()
        let effects = s.handle(.takeBreakNow, now: 300)
        #expect(effects == [.showOverlay, .recordPrompted])
        #expect(s.state == .prompting(graceDeadline: 302))
    }

    @Test func takeBreakNowIgnoredWhilePausedAndOnBreak() {
        var paused = makeScheduler(startPaused: true)
        #expect(paused.handle(.takeBreakNow, now: 10) == [])
        #expect(paused.state == .paused(until: nil))

        var breaking = onBreakScheduler(now: 1202)
        #expect(breaking.handle(.takeBreakNow, now: 1210) == [])
        #expect(breaking.state == .onBreak(deadline: 1222))
    }

    // MARK: - Wake from sleep

    @Test func wakeAfterLongSleepStartsFreshInterval() {
        var s = makeScheduler()
        let effects = s.handle(.systemWoke(sleepDuration: 3600), now: 900)
        #expect(effects == [])
        #expect(s.state == .working(deadline: 900 + 1200, deferred: false))
    }

    @Test func wakeAfterShortSleepChangesNothing() {
        var s = makeScheduler()
        let effects = s.handle(.systemWoke(sleepDuration: 60), now: 900)
        #expect(effects == [])
        #expect(s.state == .working(deadline: 1200, deferred: false))
    }

    @Test func wakeDuringBreakHidesOverlayAndRestarts() {
        var s = onBreakScheduler(now: 1202)
        let effects = s.handle(.systemWoke(sleepDuration: 3600), now: 1500)
        #expect(effects == [.hideOverlay])
        #expect(s.state == .working(deadline: 1500 + 1200, deferred: false))
    }

    @Test func wakeWhilePausedStaysPaused() {
        var s = makeScheduler(startPaused: true)
        let effects = s.handle(.systemWoke(sleepDuration: 3600), now: 900)
        #expect(effects == [])
        #expect(s.state == .paused(until: nil))
    }

    // MARK: - Settings changes

    @Test func settingsChangedClampsWorkingDeadline() {
        var s = makeScheduler() // deadline 1200
        var newConfig = config
        newConfig.workInterval = 300
        _ = s.handle(.settingsChanged(newConfig), now: 100)
        #expect(s.state == .working(deadline: 400, deferred: false))
    }

    @Test func settingsChangedKeepsNearerDeadline() {
        var s = makeScheduler() // deadline 1200
        var newConfig = config
        newConfig.workInterval = 7200
        _ = s.handle(.settingsChanged(newConfig), now: 100)
        // Existing deadline is nearer than now + new interval; unchanged.
        #expect(s.state == .working(deadline: 1200, deferred: false))
    }

    @Test func settingsChangedAppliesToNextCycle() {
        var s = makeScheduler()
        var newConfig = config
        newConfig.workInterval = 600
        newConfig.breakDuration = 30
        _ = s.handle(.settingsChanged(newConfig), now: 100)
        _ = s.handle(.timerFired, now: 700)
        _ = s.handle(.quietCheckPassed, now: 700)
        _ = s.handle(.graceElapsed, now: 702)
        #expect(s.state == .onBreak(deadline: 702 + 30))
    }

    // MARK: - Honest accounting

    @Test func fullCycleEmitsExactlyOneOutcome() {
        var s = makeScheduler()
        var effects: [Effect] = []
        effects += s.handle(.timerFired, now: 1200)
        effects += s.handle(.quietCheckPassed, now: 1200)
        effects += s.handle(.graceElapsed, now: 1202)
        effects += s.handle(.snoozed, now: 1210)
        effects += s.handle(.timerFired, now: 1390)
        effects += s.handle(.quietCheckPassed, now: 1390)
        effects += s.handle(.graceElapsed, now: 1392)
        effects += s.handle(.breakCompleted, now: 1412)

        #expect(effects.filter { $0 == .recordPrompted }.count == 1)
        #expect(effects.filter { $0 == .recordCompleted }.count == 1)
        #expect(effects.filter { $0 == .recordSkipped }.count == 0)
        #expect(effects.filter { $0 == .recordSnoozed }.count == 1)
    }
}
