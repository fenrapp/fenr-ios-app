import DesignSystem
import SwiftUI

struct RideNavigationTopControls: View {
    static let height: CGFloat = 48

    let state: RideNavigationViewState
    @Binding var activeMapSelector: RideNavigationMapSelector?
    let onClose: () -> Void
    let onToggleVoice: () -> Void
    let onOverview: () -> Void
    let onRecenter: () -> Void
    let onMapHeadingUp: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DesignSpace.small) {
            routeHeader
            Spacer(minLength: DesignSpace.medium)
            rightControls
        }
    }

    private var rightControls: some View {
        HStack(spacing: DesignSpace.small) {
            mapControls
            if let altitudeText = state.altitudeText {
                RideNavigationAltitudeChip(
                    value: altitudeText,
                    unit: state.altitudeUnit
                )
            }
        }
    }

    private var mapControls: some View {
        RideNavigationMapControls(
            state: state,
            onToggleVoice: onToggleVoice,
            onOverview: onOverview,
            onRecenter: onRecenter,
            onMapHeadingUp: onMapHeadingUp,
            activeSelector: $activeMapSelector
        )
    }

    private var routeHeader: some View {
        HStack(spacing: DesignSpace.small) {
            Button(
                action: onClose,
                label: { RideNavigationMapControlLabel(systemImage: "xmark") }
            )
            .buttonStyle(.plain)
            .accessibilityLabel(state.activity == .preview
                ? String(localized: .rideNavigationCloseRoute)
                : String(localized: .rideNavigationEndRide))

            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                HStack(spacing: DesignSpace.extraSmall) {
                    recordingIndicator
                    Text(state.routeTitle ?? activityTitle)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                }
                Text(verbatim: "\(state.distanceText) · \(state.elapsedText)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, DesignSpace.medium)
            .frame(minWidth: Constants.routeHeaderMinimumWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: Self.height)
        .rideNavigationGlassSurface(cornerRadius: Constants.controlRadius)
    }

    @ViewBuilder
    private var recordingIndicator: some View {
        if state.activity == .recording || state.activity == .paused {
            Circle()
                .fill(state.activity == .paused ? DesignColor.warning : DesignColor.critical)
                .frame(width: Constants.recordingIndicatorSize, height: Constants.recordingIndicatorSize)
        }
    }

    private var activityTitle: String {
        switch state.activity {
        case .recording, .paused: String(localized: .rideNavigationRecordingRide)
        case .navigating: String(localized: .rideNavigationNavigation)
        case .following: String(localized: .rideNavigationEnduroNavigation)
        case .preview: String(localized: .rideNavigationRoutePreview)
        }
    }

    private enum Constants {
        static let controlRadius: CGFloat = 24
        static let recordingIndicatorSize: CGFloat = 8
        static let routeHeaderMinimumWidth: CGFloat = 220
    }
}
