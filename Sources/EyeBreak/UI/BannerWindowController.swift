import AppKit
import SwiftUI

// Small transient banners for secondary reminders (PRD P1-4): ~340×80 pt at
// .statusBar level, top-right of the main screen, auto-dismiss after 10 s or
// on click. A non-activating panel so it never interrupts typing focus.
final class BannerWindowController {
    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?

    func show(text: String) {
        dismiss(animated: false)

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let size = NSSize(width: 340, height: 80)
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.maxX - size.width - 16,
            y: visible.maxY - size.height - 16
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: BannerView(text: text) { [weak self] in
            self?.dismiss(animated: true)
        })

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = reduceMotion ? 1 : 0
        panel.orderFrontRegardless()
        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 1
            }
        }
        self.panel = panel

        let work = DispatchWorkItem { [weak self] in self?.dismiss(animated: true) }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
    }

    func dismiss(animated: Bool) {
        dismissWork?.cancel()
        dismissWork = nil
        guard let panel else { return }
        self.panel = nil
        if animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        } else {
            panel.orderOut(nil)
        }
    }
}

private struct BannerView: View {
    let text: String
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "eye")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 12.5))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1))
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
