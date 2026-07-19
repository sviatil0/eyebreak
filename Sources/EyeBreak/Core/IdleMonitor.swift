import AppKit
import CoreGraphics

// Idle detection via CGEventSource (PRD P0-4). Polls every 10 s; this API
// needs no Accessibility permission. Also translates sleep/wake into events.
final class IdleMonitor {
    var onIdle: (() -> Void)?
    var onActive: (() -> Void)?
    var onWake: ((TimeInterval) -> Void)?
    /// Threshold read on every poll so settings changes apply immediately.
    var thresholdProvider: () -> TimeInterval = { 300 }

    private var timer: DispatchSourceTimer?
    private var reportedIdle = false
    private var sleepBegan: Date?
    private var observers: [NSObjectProtocol] = []

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 10, repeating: 10, leeway: .seconds(2))
        timer.setEventHandler { [weak self] in self?.poll() }
        timer.resume()
        self.timer = timer

        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.sleepBegan = Date()
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // Wall clock is only used to measure the sleep gap itself; all
            // scheduling deadlines stay monotonic.
            let duration = self.sleepBegan.map { Date().timeIntervalSince($0) } ?? 0
            self.sleepBegan = nil
            self.reportedIdle = false
            self.onWake?(duration)
        })
    }

    func stop() {
        timer?.cancel()
        timer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    private func poll() {
        let idle = Self.secondsSinceLastInput()
        let threshold = thresholdProvider()
        if !reportedIdle, idle > threshold {
            reportedIdle = true
            onIdle?()
        } else if reportedIdle, idle < 10 {
            reportedIdle = false
            onActive?()
        }
    }

    /// kCGAnyInputEventType is `CGEventType(rawValue: ~0)` in the C headers;
    /// the Swift raw-value initializer may reject it, so fall back to the
    /// minimum over concrete input event types (failure policy: assume active).
    static func secondsSinceLastInput() -> TimeInterval {
        if let anyInput = CGEventType(rawValue: UInt32.max) {
            return CGEventSource.secondsSinceLastEventType(
                .combinedSessionState, eventType: anyInput)
        }
        let types: [CGEventType] = [
            .keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown,
            .otherMouseDown, .mouseMoved, .scrollWheel,
            .leftMouseDragged, .rightMouseDragged,
        ]
        return types
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }
}
