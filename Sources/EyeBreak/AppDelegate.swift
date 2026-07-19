import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsStore: SettingsStore!
    private var statsStore: StatsStore!
    private var driver: SchedulerDriver!
    private var idleMonitor: IdleMonitor!
    private var quietMonitor: QuietModeMonitor!
    private var menuBar: MenuBarController!
    private var overlay: OverlayWindowController!
    private var banner: BannerWindowController!
    private var reminders: SecondaryReminders!

    private var statusTickTimer: DispatchSourceTimer?
    private var settingsSubscription: AnyCancellable?
    private var lastAppliedSettings: Settings?

    private var windows: [String: NSWindow] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore = SettingsStore()
        statsStore = StatsStore()
        driver = SchedulerDriver(settings: settingsStore.settings, stats: statsStore)
        idleMonitor = IdleMonitor()
        quietMonitor = QuietModeMonitor()
        menuBar = MenuBarController()
        overlay = OverlayWindowController()
        banner = BannerWindowController()
        reminders = SecondaryReminders()

        wire()

        idleMonitor.start()
        reminders.start()
        driver.start()

        if !settingsStore.settings.hasCompletedWelcome {
            showWelcome()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Persist stats on termination (PRD P1-3).
        statsStore.save()
        settingsStore.save()
    }

    // MARK: - Wiring

    private func wire() {
        quietMonitor.settingsProvider = { [weak self] in
            self?.settingsStore.settings ?? Settings()
        }

        driver.quietCheck = { [weak self] in
            self?.quietMonitor.isQuiet() ?? false
        }
        driver.showOverlay = { [weak self] in
            guard let self else { return }
            self.overlay.show(
                breakSeconds: self.settingsStore.settings.breakDurationSec,
                snoozeMinutes: max(1, self.settingsStore.settings.snoozeDurationSec / 60)
            )
        }
        driver.hideOverlay = { [weak self] in self?.overlay.hide() }
        driver.showCompletionThenHide = { [weak self] in self?.overlay.completeAndHide() }
        driver.startBreakCountdown = { [weak self] seconds in
            self?.overlay.beginCountdown(seconds: seconds)
        }
        driver.onStateChange = { [weak self] in self?.refreshStatusItem() }

        overlay.onSnooze = { [weak self] in self?.driver.snooze() }
        overlay.onSkip = { [weak self] in self?.driver.skip() }

        idleMonitor.thresholdProvider = { [weak self] in
            Double(self?.settingsStore.settings.idleThresholdSec ?? 300)
        }
        idleMonitor.onIdle = { [weak self] in self?.driver.idleDetected() }
        idleMonitor.onActive = { [weak self] in self?.driver.activityResumed() }
        idleMonitor.onWake = { [weak self] duration in
            self?.driver.systemWoke(sleepDuration: duration)
        }

        menuBar.showCountdownProvider = { [weak self] in
            self?.settingsStore.settings.showCountdownInMenuBar ?? true
        }
        menuBar.onTakeBreak = { [weak self] in self?.driver.takeBreakNow() }
        menuBar.onPause = { [weak self] seconds in
            guard let self else { return }
            self.settingsStore.settings.pauseUntilReenabled = (seconds == nil)
            self.driver.pause(seconds: seconds)
        }
        menuBar.onResume = { [weak self] in
            guard let self else { return }
            self.settingsStore.settings.pauseUntilReenabled = false
            self.driver.resume()
        }
        menuBar.onSettings = { [weak self] in self?.showSettings() }
        menuBar.onStats = { [weak self] in self?.showStats() }
        menuBar.onWhenToGetChecked = { [weak self] in self?.showWhenToGetChecked() }
        menuBar.onQuit = { NSApp.terminate(nil) }

        reminders.settingsProvider = { [weak self] in
            self?.settingsStore.settings ?? Settings()
        }
        reminders.contextProvider = { [weak self] in
            guard let self else {
                return SecondaryReminders.Context(
                    canShowBanner: false, accumulatesActiveTime: false,
                    secondsToNextBreak: nil, secondsSinceLastBreakEnd: nil)
            }
            return SecondaryReminders.Context(
                canShowBanner: self.driver.canShowBanner && !self.quietMonitor.isQuiet(),
                accumulatesActiveTime: self.driver.canShowBanner,
                secondsToNextBreak: self.driver.secondsToNextBreak,
                secondsSinceLastBreakEnd: self.driver.secondsSinceLastBreakEnd
            )
        }
        reminders.showBanner = { [weak self] text in self?.banner.show(text: text) }

        lastAppliedSettings = settingsStore.settings
        settingsSubscription = settingsStore.$settings
            .removeDuplicates()
            .sink { [weak self] newSettings in
                guard let self else { return }
                // Only re-feed the scheduler when durations actually change,
                // so unrelated toggles don't clamp deadlines.
                if let previous = self.lastAppliedSettings,
                   previous.schedulerConfig != newSettings.schedulerConfig {
                    self.driver.settingsChanged(newSettings)
                }
                self.lastAppliedSettings = newSettings
                self.refreshStatusItem()
            }
    }

    // MARK: - Status item

    private func refreshStatusItem() {
        let display: MenuBarController.Display
        switch driver.state {
        case .working(let deadline, let deferred):
            if deferred {
                display = .waiting
            } else {
                display = .countdown(secondsRemaining: Int(max(0, deadline - SchedulerDriver.monotonicNow())))
            }
        case .snoozed(let deadline, let deferred):
            display = deferred
                ? .waiting
                : .countdown(secondsRemaining: Int(max(0, deadline - SchedulerDriver.monotonicNow())))
        case .prompting, .onBreak:
            display = .onBreak
        case .paused:
            display = .paused(until: driver.pausedUntilDate)
        case .idle:
            display = .idle
        }
        menuBar.update(display: display)
        rescheduleStatusTick(for: display)
    }

    /// Countdown title refresh: at most once per 30 s normally, once per
    /// second only inside the final minute (PRD P2-2 CPU budget).
    private func rescheduleStatusTick(for display: MenuBarController.Display) {
        statusTickTimer?.cancel()
        statusTickTimer = nil
        guard case .countdown(let seconds) = display, seconds > 0 else { return }

        let interval: Double = seconds <= 60 ? 1 : 30
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in self?.refreshStatusItem() }
        timer.resume()
        statusTickTimer = timer
    }

    // MARK: - Windows

    private func showSettings() {
        presentWindow(id: "settings", title: "EyeBreak Settings") {
            SettingsView(store: self.settingsStore)
        }
    }

    private func showStats() {
        presentWindow(id: "stats", title: CopyStrings.statsTitle) {
            StatsView(store: self.statsStore)
        }
    }

    private func showWhenToGetChecked() {
        presentWindow(id: "checked", title: CopyStrings.checkedTitle) {
            WhenToGetCheckedView()
        }
    }

    private func showWelcome() {
        presentWindow(id: "welcome", title: CopyStrings.welcomeTitle) {
            WelcomeView(
                onStart: { [weak self] in
                    self?.settingsStore.settings.hasCompletedWelcome = true
                    self?.closeWindow(id: "welcome")
                },
                onOpenSettings: { [weak self] in
                    self?.settingsStore.settings.hasCompletedWelcome = true
                    self?.closeWindow(id: "welcome")
                    self?.showSettings()
                }
            )
        }
    }

    private func presentWindow<Content: View>(id: String, title: String, @ViewBuilder content: () -> Content) {
        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: content())
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        windows[id] = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            self?.windows[id] = nil
        }
        // The app is LSUIElement/.accessory; activate transiently to show windows.
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeWindow(id: String) {
        windows[id]?.close()
    }
}
