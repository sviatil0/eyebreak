import SwiftUI

// Visual identity (issue #3): one calm accent for the whole app.
// "Dusk blue" is deliberately low-saturation — the overlay's job is a
// calm release, not spectacle. No other accent colors may be introduced.
extension Color {
    static let duskBlue = Color(red: 0.66, green: 0.78, blue: 0.90)
}
