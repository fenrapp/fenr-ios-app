import DesignSystem
import SwiftUI

enum RideNavigationMapSelector {
    case source
}

struct RideNavigationMapControls: View {
    let state: RideNavigationViewState
    let onToggleVoice: () -> Void
    let onOverview: () -> Void
    let onRecenter: () -> Void
    let onMapHeadingUp: (Bool) -> Void
    @Binding var activeSelector: RideNavigationMapSelector?

    var body: some View {
        RideNavigationGlassGroup(spacing: DesignSpace.extraSmall) {
            HStack(spacing: DesignSpace.extraSmall) {
                RideNavigationMapSourceMenu(
                    sources: state.mapSources,
                    mode: state.mapMode,
                    selectedStyleID: state.selectedMapStyleID,
                    allowsFocus: state.allowsFocusMapStyle,
                    isPresented: activeSelector == .source,
                    onPresentationChange: { activeSelector = $0 ? .source : nil }
                )
                RideNavigationMapOrientationButton(
                    isHeadingUp: state.isHeadingUp,
                    onToggle: { onMapHeadingUp(!state.isHeadingUp) }
                )
                controlButton(
                    systemImage: state.isVoiceMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    accessibilityLabel: state.isVoiceMuted
                        ? .rideNavigationEnableVoiceGuidance
                        : .rideNavigationMuteVoiceGuidance,
                    action: onToggleVoice
                )
                controlButton(
                    systemImage: "arrow.up.left.and.arrow.down.right",
                    accessibilityLabel: .rideNavigationShowRouteOverview,
                    action: onOverview
                )
                controlButton(
                    systemImage: "location.fill",
                    accessibilityLabel: .rideNavigationRecenterMap,
                    action: onRecenter
                )
            }
        }
    }

    private func controlButton(
        systemImage: String,
        accessibilityLabel: LocalizedStringResource,
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
    var onOfflineMaps: (() -> Void)?
    let onMapStyle: (String) -> Void
    @Binding var activeSelector: RideNavigationMapSelector?

    @ViewBuilder
    var body: some View {
        switch activeSelector {
        case .source:
            RideNavigationMapSourcePicker(
                sources: state.mapSources,
                selectedStyleID: state.selectedMapStyleID,
                allowsFocus: state.allowsFocusMapStyle,
                mode: state.mapMode,
                coverageNotice: state.mapScene.offlineNotice,
                onOfflineMaps: onOfflineMaps
            ) { styleID in
                onMapStyle(styleID)
                if !state.mapMode.choices.contains(where: { $0.id == styleID }) { activeSelector = nil }
            }
        case nil:
            EmptyView()
        }
    }
}
