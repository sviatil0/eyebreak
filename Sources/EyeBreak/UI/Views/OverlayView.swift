import AppKit
import SwiftUI

final class OverlayModel: ObservableObject {
    enum Phase {
        case grace, counting, done
    }

    @Published var phase: Phase = .grace
    @Published var remaining: Int = 20
    @Published var snoozeMinutes: Int = 3
    var onSnooze: (() -> Void)?
    var onSkip: (() -> Void)?
}

struct OverlayView: View {
    @ObservedObject var model: OverlayModel
    let showContent: Bool

    // ≈75% black; fully opaque dark gray when Reduce Transparency is on.
    private var backdrop: Color {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            ? Color(white: 0.12)
            : Color.black.opacity(0.75)
    }

    var body: some View {
        ZStack {
            backdrop.ignoresSafeArea()
            if showContent {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 18) {
            if model.phase == .done {
                Text(CopyStrings.overlayDoneLine)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(.white)
            } else {
                Text(CopyStrings.overlayTitle)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.white)

                VStack(spacing: 6) {
                    Text(CopyStrings.overlayBody)
                    Text(CopyStrings.overlayBody2)
                }
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.85))

                Text("\(model.remaining) \(CopyStrings.overlayCountdownSuffix)")
                    .font(.system(size: 56, weight: .light).monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.vertical, 8)

                HStack(spacing: 16) {
                    Button(String(format: CopyStrings.overlaySnoozeButton, model.snoozeMinutes)) {
                        model.onSnooze?()
                    }
                    Button(CopyStrings.overlaySkipButton) {
                        model.onSkip?()
                    }
                }
                .buttonStyle(OverlayButtonStyle())

                Text(CopyStrings.overlayFootnote)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.top, 22)
            }
        }
        .padding(40)
    }
}

private struct OverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.3 : 0.16))
            )
    }
}
