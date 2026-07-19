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
        VStack(alignment: .leading, spacing: 20) {
            Text(CopyStrings.checkedTitle)
                .font(.system(size: 20, weight: .semibold))

            Text(CopyStrings.checkedIntro)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(.secondary)
                        Text(bullet)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 4)

            // Educational note, visually set apart by a hairline box only —
            // deliberately not an alert style.
            Text(CopyStrings.checkedItchNote)
                .font(.callout)
                .foregroundColor(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            Text(CopyStrings.checkedDisclaimer)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 560, alignment: .leading)
        .padding(24)
    }
}
