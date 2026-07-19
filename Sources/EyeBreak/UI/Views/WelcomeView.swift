import SwiftUI

// Onboarding-lite (PRD P2-1): one small window, no permission requests.
struct WelcomeView: View {
    var onStart: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(CopyStrings.welcomeTitle)
                .font(.title2.weight(.semibold))

            Text(CopyStrings.welcomeBody)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button(CopyStrings.welcomeSettings, action: onOpenSettings)
                Button(CopyStrings.welcomeStart, action: onStart)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
