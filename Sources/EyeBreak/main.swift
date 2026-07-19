import AppKit

// NSApplication bootstrap (PRD §8.1): accessory activation policy — menu-bar
// presence only, no Dock icon, no main window.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
