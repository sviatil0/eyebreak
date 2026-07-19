import AppKit
import CoreGraphics

// Best-effort automatic quiet mode (PRD P1-2): full-screen frontmost app and
// display mirroring. Failure policy: if any API call fails, assume NOT quiet —
// the break shows rather than being silently suppressed.
final class QuietModeMonitor {
    var settingsProvider: () -> Settings = { Settings() }

    func isQuiet() -> Bool {
        let settings = settingsProvider()
        if settings.quietOnFullScreen, frontmostAppIsFullScreen() { return true }
        if settings.quietOnScreenSharing, displayIsMirrored() { return true }
        return false
    }

    /// The frontmost app's topmost normal-layer window covers an entire screen.
    private func frontmostAppIsFullScreen() -> Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return false }

        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { return false }

        // The list is front-to-back; the first layer-0 window owned by the
        // frontmost app is its topmost window.
        for info in windowInfo {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == frontmost.processIdentifier,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }
            return coversAnyScreen(bounds)
        }
        return false
    }

    /// CGWindow bounds use a global top-left origin; NSScreen frames use
    /// bottom-left. Convert and compare with a small tolerance.
    private func coversAnyScreen(_ cgBounds: CGRect) -> Bool {
        guard let primary = NSScreen.screens.first else { return false }
        let globalHeight = primary.frame.maxY
        for screen in NSScreen.screens {
            let f = screen.frame
            let flipped = CGRect(
                x: f.origin.x,
                y: globalHeight - f.maxY,
                width: f.width,
                height: f.height
            )
            let tolerance: CGFloat = 1.0
            if abs(cgBounds.minX - flipped.minX) <= tolerance,
               abs(cgBounds.minY - flipped.minY) <= tolerance,
               abs(cgBounds.width - flipped.width) <= tolerance,
               abs(cgBounds.height - flipped.height) <= tolerance {
                return true
            }
        }
        return false
    }

    /// Mirroring detection. Screen-*capture* detection is unreliable without
    /// extra permissions on modern macOS, so this is mirroring plus a
    /// duplicate-bounds heuristic (documented limitation in the README).
    private func displayIsMirrored() -> Bool {
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetActiveDisplayList(UInt32(ids.count), &ids, &count) == .success,
              count > 0
        else { return false }

        let active = ids.prefix(Int(count))
        if active.contains(where: { CGDisplayIsInMirrorSet($0) != 0 }) {
            return true
        }
        // Two active displays with identical bounds also indicate mirroring.
        let bounds = active.map { CGDisplayBounds($0) }
        for i in bounds.indices {
            for j in bounds.indices where j > i {
                if bounds[i].equalTo(bounds[j]) { return true }
            }
        }
        return false
    }
}
