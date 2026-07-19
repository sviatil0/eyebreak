import AppKit

// NSStatusItem + NSMenu (PRD P0-3). AppKit rather than MenuBarExtra so the
// accessory-policy app fully controls title updates and window lifecycle.
final class MenuBarController: NSObject, NSMenuDelegate {
    enum Display: Equatable {
        case countdown(secondsRemaining: Int)
        case onBreak
        case waiting
        case paused(until: Date?)
        case idle
    }

    var onTakeBreak: (() -> Void)?
    var onPause: ((Double?) -> Void)? // seconds; nil = until re-enabled
    var onResume: (() -> Void)?
    var onSettings: (() -> Void)?
    var onStats: (() -> Void)?
    var onWhenToGetChecked: (() -> Void)?
    var onQuit: (() -> Void)?
    var showCountdownProvider: () -> Bool = { true }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var display: Display = .countdown(secondsRemaining: 0)

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    override init() {
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.behavior = []
    }

    func update(display: Display) {
        self.display = display
        guard let button = statusItem.button else { return }

        func symbol(_ name: String, fallback: String) {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: fallback) {
                button.image = image
                button.title = ""
            } else {
                button.image = nil
                button.title = fallback
            }
        }

        switch display {
        case .countdown(let seconds):
            if showCountdownProvider() {
                button.image = nil
                button.title = Self.compactCountdown(seconds)
            } else {
                symbol("eye", fallback: "👁")
            }
        case .onBreak:
            button.image = nil
            button.title = "…"
        case .waiting:
            symbol("hourglass", fallback: "⏳")
        case .paused:
            symbol("pause.circle", fallback: "⏸")
        case .idle:
            symbol("moon.zzz", fallback: "z")
        }
    }

    static func compactCountdown(_ seconds: Int) -> String {
        seconds < 60 ? "\(max(0, seconds))s" : "\(Int((Double(seconds) / 60).rounded(.up)))m"
    }

    // Rebuilt lazily each time the user opens it, so state is always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        menu.addItem(makeItem(CopyStrings.menuTakeBreakNow, #selector(takeBreak)))

        if case .paused = display {
            menu.addItem(makeItem(CopyStrings.menuResume, #selector(resume)))
        } else {
            menu.addItem(makeItem(CopyStrings.menuPause30, #selector(pause30)))
            menu.addItem(makeItem(CopyStrings.menuPause60, #selector(pause60)))
            menu.addItem(makeItem(CopyStrings.menuPauseIndefinite, #selector(pauseIndefinitely)))
        }

        menu.addItem(.separator())
        menu.addItem(makeItem(CopyStrings.menuSettings, #selector(openSettings)))
        menu.addItem(makeItem(CopyStrings.menuStats, #selector(openStats)))
        menu.addItem(makeItem(CopyStrings.menuWhenToGetChecked, #selector(openChecked)))
        menu.addItem(.separator())
        menu.addItem(makeItem(CopyStrings.menuQuit, #selector(quit)))
    }

    private var statusLine: String {
        switch display {
        case .countdown(let seconds):
            return String(format: CopyStrings.menuNextBreak, Self.compactCountdown(seconds))
        case .onBreak:
            return CopyStrings.menuOnBreak
        case .waiting:
            return CopyStrings.menuWaitingQuiet
        case .paused(let until):
            guard let until else { return CopyStrings.menuPaused }
            return String(format: CopyStrings.menuPausedUntil, Self.timeFormatter.string(from: until))
        case .idle:
            return CopyStrings.menuIdle
        }
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func takeBreak() { onTakeBreak?() }
    @objc private func pause30() { onPause?(30 * 60) }
    @objc private func pause60() { onPause?(60 * 60) }
    @objc private func pauseIndefinitely() { onPause?(nil) }
    @objc private func resume() { onResume?() }
    @objc private func openSettings() { onSettings?() }
    @objc private func openStats() { onStats?() }
    @objc private func openChecked() { onWhenToGetChecked?() }
    @objc private func quit() { onQuit?() }
}
