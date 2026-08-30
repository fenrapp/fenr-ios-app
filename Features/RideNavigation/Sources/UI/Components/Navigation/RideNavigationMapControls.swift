import DesignSystem
import SwiftUI

enum RideNavigationMapSelector {
    case source
    case orientation
}

struct RideNavigationMapControls: View {
    let state: RideNavigationViewState
    let onToggleVoice: () -> Void
    let onOverview: () -> Void
    let onRecenter: () -> Void
    @Binding var activeSelector: RideNavigationMapSelector?

    var body: some View {
        RideNavigationGlassGroup(spacing: DesignSpace.extraSmall) {
            HStack(spacing: DesignSpace.extraSmall) {
                RideNavigationMapSourceMenu(
                    sources: state.mapSources,
                    selectedStyleID: state.selectedMapStyleID,
                    allowsFocus: state.allowsFocusMapStyle,
                    isPresented: activeSelector == .source,
                    onPresentationChange: { activeSelector = $0 ? .source : nil }
                )
                RideNavigationMapOrientationMenu(
                    isHeadingUp: state.isHeadingUp,
                    isPresented: activeSelector == .orientation,
                    onPresentationChange: { activeSelector = $0 ? .orientation : nil }
                )
                controlButton(
                    systemImage: state.isVoiceMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    accessibilityLabel: state.isVoiceMuted ? "Enable voice guidance" : "Mute voice guidance",
                    action: onToggleVoice
                )
                controlButton(
                    systemImage: "arrow.up.left.and.arrow.down.right",
                    accessibilityLabel: "Show route overview",
                    action: onOverview
                )
                controlButton(
                    systemImage: "location.fill",
                    accessibilityLabel: "Recenter map",
                    action: onRecenter
                )
            }
        }
    }

    private func controlButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(
            action: action,
            label: { RideNavigationMapControlLabel(systemImage: systemImage) }
        )
        .buttonStyle(.plain)
        .rideNavigationGlassControl()
        .accessibilityLabel(accessibilityLabel)
    }
}

struct RideNavigationMapSelectorPanel: View {
    let state: RideNavigationViewState
    let onMapStyle: (String) -> Void
    let onMapHeadingUp: (Bool) -> Void
    @Binding var activeSelector: RideNavigationMapSelector?

    @ViewBuilder
    var body: some View {
        switch activeSelector {
        case .source:
            RideNavigationMapSourcePicker(
                sources: state.mapSources,
                selectedStyleID: state.selectedMapStyleID,
                allowsFocus: state.allowsFocusMapStyle
            ) { styleID in
                onMapStyle(styleID)
                activeSelector = nil
            }
        case .orientation:
            RideNavigationMapOrientationPicker(isHeadingUp: state.isHeadingUp) { isHeadingUp in
                onMapHeadingUp(isHeadingUp)
                activeSelector = nil
            }
        case nil:
            EmptyView()
        }
    }
}
