import DesignSystem
import SwiftUI

struct RideNavigationRoutePreferencesView: View {
    let avoidsTolls: Bool
    let avoidsHighways: Bool
    let isLoading: Bool
    let onAvoidTolls: (Bool) -> Void
    let onAvoidHighways: (Bool) -> Void

    var body: some View {
        HStack(spacing: DesignSpace.extraSmall) {
            preferenceButton(
                title: "Avoid Tolls",
                systemImage: "creditcard.fill",
                isSelected: avoidsTolls,
                action: { onAvoidTolls(!avoidsTolls) }
            )
            preferenceButton(
                title: "Avoid Highways",
                systemImage: "road.lanes",
                isSelected: avoidsHighways,
                action: { onAvoidHighways(!avoidsHighways) }
            )
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, DesignSpace.extraSmall)
                    .accessibilityLabel("Updating routes")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func preferenceButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: isSelected ? "checkmark.circle.fill" : systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, DesignSpace.small)
                .frame(minHeight: Constants.controlHeight)
                .background(
                    isSelected ? DesignColor.controlSurface : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .rideNavigationGlassChip()
        .accessibilityValue(isSelected ? "On" : "Off")
    }

    private enum Constants {
        static let controlHeight: CGFloat = 44
    }
}
