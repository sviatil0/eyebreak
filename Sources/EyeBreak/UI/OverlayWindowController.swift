import AppKit
import SwiftUI

// Borderless windows refuse key status by default; the overlay must become
// key so Escape and button focus reach it (PRD §8.5).
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// Per-screen borderless break overlays (PRD P0-2, §8.5). Deliberately
// overlay-based, not Notification Center-based: works from a bare SPM
// executable with no entitlements.
final class OverlayWindowController {
    var onSnooze: (() -> Void)?
    var onSkip: (() -> Void)?

    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var visualTimer: DispatchSourceTimer?
    private var screenObserver: NSObjectProtocol?
    private let model = OverlayModel()

    private(set) var isVisible = false

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func show(breakSeconds: Int, snoozeMinutes: Int) {
        guard !isVisible else { return }
        isVisible = true

        model.phase = .grace
        model.remaining = breakSeconds
        model.snoozeMinutes = snoozeMinutes
        model.onSnooze = { [weak self] in self?.onSnooze?() }
        model.onSkip = { [weak self] in self?.onSkip?() }

        // Remember the active app so dismissal never strands the user's
        // keystrokes in the wrong place (PRD P0-2).
        previousApp = NSWorkspace.shared.frontmostApplication

        buildWindows()

        // Overlay creation failure logs and skips the cycle without crashing
        // (PRD §8.4 failure policy).
        guard !windows.isEmpty else {
            FileHandle.standardError.write(Data("EyeBreak: could not create overlay windows; skipping this break\n".utf8))
            isVisible = false
            onSkip?()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
        windows.dropFirst().forEach { $0.orderFront(nil) }
        fade(to: 1, duration: 2)

        // Escape always skips (PRD P0-2).
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.onSkip?()
                return nil
            }
            return event
        }

        // Rebuild on display changes while visible (PRD §8.5).
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.isVisible else { return }
            self.windows.forEach { $0.orderOut(nil) }
            self.buildWindows()
            self.windows.first?.makeKeyAndOrderFront(nil)
            self.windows.dropFirst().forEach { $0.orderFront(nil) }
            self.windows.forEach { $0.alphaValue = 1 }
        }
    }

    /// Called at graceElapsed: starts the visible countdown. Completion is
    /// decided by the scheduler's monotonic deadline, not this display timer.
    func beginCountdown(seconds: Int) {
        guard isVisible else { return }
        model.phase = .counting
        model.remaining = seconds

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            if self.model.remaining > 0 { self.model.remaining -= 1 }
        }
        timer.resume()
        visualTimer = timer
    }

    /// Gentle completion line for 1.5 s, then fade out.
    func completeAndHide() {
        guard isVisible else { return }
        stopVisualTimer()
        model.phase = .done
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.hide()
        }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        stopVisualTimer()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil

        let windowsToClose = windows
        windows = []
        let finish = { [weak self] in
            windowsToClose.forEach { $0.orderOut(nil) }
            self?.previousApp?.activate()
            self?.previousApp = nil
        }
        if reduceMotion {
            finish()
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                windowsToClose.forEach { $0.animator().alphaValue = 0 }
            }, completionHandler: finish)
        }
    }

    // MARK: - Private

    private func buildWindows() {
        windows = []
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        // Content goes on the screen with the mouse pointer; others get a
        // plain dim (PRD §8.5).
        let mouse = NSEvent.mouseLocation
        let contentScreen = screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main ?? screens[0]

        for screen in screens {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            // .screenSaver level so the overlay sits above normal windows and
            // full-screen Spaces without needing elevated permissions.
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.alphaValue = reduceMotion ? 1 : 0

            let showContent = screen == contentScreen
            let root = OverlayView(model: model, showContent: showContent)
            window.contentView = NSHostingView(rootView: root)
            if showContent {
                windows.insert(window, at: 0)
            } else {
                windows.append(window)
            }
        }
    }

    private func fade(to alpha: CGFloat, duration: TimeInterval) {
        if reduceMotion {
            windows.forEach { $0.alphaValue = alpha }
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            windows.forEach { $0.animator().alphaValue = alpha }
        }
    }

    private func stopVisualTimer() {
        visualTimer?.cancel()
        visualTimer = nil
    }
}
