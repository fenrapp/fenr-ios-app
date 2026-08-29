import DesignSystem
import SwiftUI

struct RideNavigationMapControls: View {
    let state: RideNavigationViewState
    let onMapStyle: (String) -> Void
    let onMapHeadingUp: (Bool) -> Void
    let onToggleVoice: () -> Void
    let onOverview: () -> Void
    let onRecenter: () -> Void

    var body: some View {
        RideNavigationGlassGroup(spacing: DesignSpace.extraSmall) {
            HStack(spacing: DesignSpace.extraSmall) {
                RideNavigationMapSourceMenu(
                    sources: state.mapSources,
                    selectedStyleID: state.selectedMapStyleID,
                    allowsFocus: state.allowsFocusMapStyle,
                    onSelect: onMapStyle
                )
                RideNavigationMapOrientationMenu(
                    isHeadingUp: state.isHeadingUp,
                    onSelect: onMapHeadingUp
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
