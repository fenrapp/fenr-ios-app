import SwiftUI

struct RideNavigationMapOrientationButton: View {
    let isHeadingUp: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            RideNavigationMapControlLabel(systemImage: "safari.fill")
        }
        .buttonStyle(.plain)
        .rideNavigationGlassControl()
        .accessibilityLabel(String(localized: .rideNavigationMapOrientationAccessibility(
            String(localized: isHeadingUp ? .rideNavigationHeadingUp : .rideNavigationNorthUp)
        )))
        .accessibilityHint(isHeadingUp ? .rideNavigationNorthUp : .rideNavigationHeadingUp)
    }
}
