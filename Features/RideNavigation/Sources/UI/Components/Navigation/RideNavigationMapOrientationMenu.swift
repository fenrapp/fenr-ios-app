import SwiftUI

struct RideNavigationMapOrientationMenu: View {
    let isHeadingUp: Bool
    let onSelect: (Bool) -> Void

    var body: some View {
        Menu {
            orientationButton(
                title: "Heading Up",
                systemImage: "location.north.fill",
                isSelected: isHeadingUp,
                value: true
            )
            orientationButton(
                title: "North Up",
                systemImage: "location.north.circle",
                isSelected: !isHeadingUp,
                value: false
            )
        } label: {
            RideNavigationMapControlLabel(systemImage: "safari.fill")
        }
        .buttonStyle(.plain)
        .rideNavigationGlassControl()
        .accessibilityLabel("Map orientation, \(isHeadingUp ? "Heading Up" : "North Up")")
    }

    private func orientationButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        value: Bool
    ) -> some View {
        Button(
            action: { onSelect(value) },
            label: { Label(title, systemImage: isSelected ? "checkmark" : systemImage) }
        )
    }
}
