import SwiftUI

// Educational escalation copy only (PRD P1-5) — verbatim strings from §10.
// The app never diagnoses.
struct WhenToGetCheckedView: View {
    private let bullets = [
        CopyStrings.checkedBullet1,
        CopyStrings.checkedBullet2,
        CopyStrings.checkedBullet3,
        CopyStrings.checkedBullet4,
        CopyStrings.checkedBullet5,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(CopyStrings.checkedTitle)
                .font(.title2.weight(.semibold))

            Text(CopyStrings.checkedIntro)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                        Text(bullet)
                    }
                }
            }

            Divider()

            Text(CopyStrings.checkedItchNote)
                .font(.callout)
                .foregroundColor(.secondary)

            Text(CopyStrings.checkedDisclaimer)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(width: 420)
    }
}
