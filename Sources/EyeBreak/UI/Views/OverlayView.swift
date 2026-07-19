import AppKit
import SwiftUI

final class OverlayModel: ObservableObject {
    enum Phase {
        case grace, counting, done
    }

    @Published var phase: Phase = .grace
    @Published var remaining: Int = 20
    @Published var total: Int = 20
    @Published var snoozeMinutes: Int = 3
    var onSnooze: (() -> Void)?
    var onSkip: (() -> Void)?
}

// Break overlay (issue #3 visual identity): radial vignette scrim + dark
// material card + thin accent countdown ring. Calm release, not spectacle.
struct OverlayView: View {
    @ObservedObject var model: OverlayModel
    let showContent: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Fully opaque dark gray when Reduce Transparency is on (PRD P2-2).
    private var reduceTransparency: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }

    var body: some View {
        ZStack {
            scrim.ignoresSafeArea()
            if showContent {
                card
            }
        }
    }

    // MARK: - Scrim

    // Radial vignette: gently darker toward the edges so text stays legible
    // over bright busy content everywhere, and focus settles at the center.
    @ViewBuilder
    private var scrim: some View {
        if reduceTransparency {
            Color(white: 0.12)
        } else {
            GeometryReader { geo in
                RadialGradient(
                    colors: [.black.opacity(0.60), .black.opacity(0.80)],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(geo.size.width, geo.size.height) * 0.75
                )
            }
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 28) {
            if model.phase == .done {
                Text(CopyStrings.overlayDoneLine)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
            } else {
                VStack(spacing: 12) {
                    Text(CopyStrings.overlayTitle)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))

                    VStack(spacing: 4) {
                        Text(CopyStrings.overlayBody)
                        Text(CopyStrings.overlayBody2)
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                }

                countdownRing

                HStack(spacing: 12) {
                    Button(String(format: CopyStrings.overlaySnoozeButton, model.snoozeMinutes)) {
                        model.onSnooze?()
                    }
                    Button(CopyStrings.overlaySkipButton) {
                        model.onSkip?()
                    }
                }
                .buttonStyle(OverlayCapsuleButtonStyle())

                Text(CopyStrings.overlayFootnote)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 56)
        .background(Color.black.opacity(0.30))
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 10)
    }

    // MARK: - Countdown ring

    private var fractionRemaining: CGFloat {
        guard model.total > 0 else { return 0 }
        return CGFloat(model.remaining) / CGFloat(model.total)
    }

    // Reserve numeral width from the (fixed-per-break) total so the layout
    // never shifts as digits count down, e.g. "10" -> "9".
    private var reservedNumeralWidth: CGFloat {
        CGFloat(String(model.total).count) * 29
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 5)
            // Reduce Motion: static full ring; the numerals carry the countdown.
            Circle()
                .trim(from: 0, to: reduceMotion ? 1 : fractionRemaining)
                .stroke(Color.duskBlue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: fractionRemaining)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(model.remaining)")
                    .font(.system(size: 48, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.white.opacity(0.95))
                    .frame(minWidth: reservedNumeralWidth, alignment: .trailing)
                Text(CopyStrings.overlayCountdownSuffix)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.70))
            }
        }
        .frame(width: 130, height: 130)
        .padding(.vertical, 4)
    }
}

// Quiet capsule buttons: fill-only state changes (no layout shift), system
// focus ring preserved for keyboard navigation (PRD P0-2).
private struct OverlayCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CapsuleBody(configuration: configuration)
    }

    private struct CapsuleBody: View {
        let configuration: ButtonStyle.Configuration
        @State private var hovering = false

        private var fillOpacity: Double {
            if configuration.isPressed { return 0.20 }
            return hovering ? 0.16 : 0.10
        }

        var body: some View {
            configuration.label
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 18)
                .frame(height: 34)
                .background(Capsule().fill(Color.white.opacity(fillOpacity)))
                .contentShape(Capsule())
                .onHover { hovering = $0 }
        }
    }
}
