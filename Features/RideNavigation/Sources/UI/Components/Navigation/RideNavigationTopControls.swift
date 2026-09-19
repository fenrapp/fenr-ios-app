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
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: DesignSpace.small) {
                routeHeader
                    .frame(
                        minWidth: Constants.minimumHeaderWidth, idealWidth: Constants.minimumHeaderWidth,
                        maxWidth: .infinity, alignment: .leading
                    )
                Spacer(minLength: DesignSpace.medium)
                rightControls
                    .fixedSize(horizontal: true, vertical: true)
            }
            VStack(alignment: .leading, spacing: DesignSpace.small) {
                routeHeader
                ScrollView(.horizontal) {
                    rightControls
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("rideNavigation.topControls")
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
                    .accessibilityIdentifier("rideNavigation.progress")
            }
            .padding(.trailing, DesignSpace.medium)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSpace.extraExtraSmall)
        .frame(minHeight: Self.height)
        .fixedSize(horizontal: false, vertical: true)
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
        static let minimumHeaderWidth: CGFloat = 180
        static let controlRadius: CGFloat = 24
        static let recordingIndicatorSize: CGFloat = 8
    }
}
