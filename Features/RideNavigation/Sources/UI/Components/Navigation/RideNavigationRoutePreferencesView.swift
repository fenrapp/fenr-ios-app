import DesignSystem
import SwiftUI

struct RideNavigationRoutePlanningOptionsView: View {
    let state: RideNavigationViewState
    let onSelectRouteOption: (Int) -> Void
    let onAvoidTolls: (Bool) -> Void
    let onAvoidHighways: (Bool) -> Void

    var body: some View {
        VStack(spacing: DesignSpace.extraSmall) {
            if state.activity == .preview, state.roadRouteOptions.count > 1 {
                RideNavigationRouteOptionsView(
                    options: state.roadRouteOptions,
                    onSelect: onSelectRouteOption
                )
                .allowsHitTesting(!state.isCalculatingRoadRoutes)
                .opacity(state.isCalculatingRoadRoutes ? Constants.loadingOpacity : 1)
            }
            if state.showsRoadRoutePreferences {
                RideNavigationRoutePreferencesView(
                    avoidsTolls: state.avoidsTolls,
                    avoidsHighways: state.avoidsHighways,
                    isLoading: state.isCalculatingRoadRoutes,
                    onAvoidTolls: onAvoidTolls,
                    onAvoidHighways: onAvoidHighways
                )
            }
        }
    }

    private enum Constants {
        static let loadingOpacity = 0.55
    }
}

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
