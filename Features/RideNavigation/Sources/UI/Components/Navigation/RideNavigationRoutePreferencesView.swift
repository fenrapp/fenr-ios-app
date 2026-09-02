import DesignSystem
import SwiftUI

struct RideNavigationRoutePlanningOptionsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
    }

    private enum Constants {
        static let loadingOpacity = 0.55
    }
}

struct RideNavigationRoutePreferencesView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let avoidsTolls: Bool
    let avoidsHighways: Bool
    let isLoading: Bool
    let onAvoidTolls: (Bool) -> Void
    let onAvoidHighways: (Bool) -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DesignSpace.extraSmall) { preferenceControls }
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: DesignSpace.extraSmall) { preferenceControls }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var preferenceControls: some View {
            preferenceButton(
                title: .rideNavigationAvoidTolls,
                systemImage: "creditcard.fill",
                isSelected: avoidsTolls,
                action: { onAvoidTolls(!avoidsTolls) }
            )
            preferenceButton(
                title: .rideNavigationAvoidHighways,
                systemImage: "road.lanes",
                isSelected: avoidsHighways,
                action: { onAvoidHighways(!avoidsHighways) }
            )
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, DesignSpace.extraSmall)
                    .accessibilityLabel(.rideNavigationUpdatingRoutes)
            }
    }

    private func preferenceButton(
        title: LocalizedStringResource,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: isSelected ? "checkmark.circle.fill" : systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(
                    horizontal: false,
                    vertical: dynamicTypeSize.isAccessibilitySize
                )
                .padding(.horizontal, DesignSpace.small)
                .frame(minHeight: Constants.controlHeight)
                .background(
                    isSelected ? DesignColor.controlSurface : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
        .fixedSize(
            horizontal: !dynamicTypeSize.isAccessibilitySize,
            vertical: dynamicTypeSize.isAccessibilitySize
        )
        .rideNavigationGlassChip()
        .accessibilityValue(String(localized: isSelected ? .rideNavigationOn : .rideNavigationOff))
    }

    private enum Constants {
        static let controlHeight: CGFloat = 44
    }
}
