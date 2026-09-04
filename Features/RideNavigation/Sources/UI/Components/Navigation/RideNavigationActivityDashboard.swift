import DesignSystem
import SwiftUI

struct RideNavigationActivityDashboard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: RideNavigationViewState
    let isFocus: Bool
    let onStart: () -> Void
    let onTogglePause: () -> Void
    let onMinimize: () -> Void
    let onReverse: () -> Void
    let onRequestTrailExit: () -> Void
    let onResumeGPX: () -> Void
    let onRequestFinish: () -> Void

    var body: some View {
        if isFocusDriving {
            focusDashboard
        } else {
            standardDashboard
        }
    }

    private var standardDashboard: some View {
        HStack(alignment: .center, spacing: DesignSpace.medium) {
            metricsGrid
            Spacer(minLength: DesignSpace.medium)
            actionsContainer(maxWidth: Constants.standardActionsWidth)
        }
        .padding(.horizontal, DesignSpace.medium)
        .padding(.vertical, DesignSpace.small)
        .frame(minHeight: Constants.dashboardHeight)
        .fixedSize(horizontal: false, vertical: true)
        .rideNavigationGlassSurface(cornerRadius: Constants.dashboardRadius)
    }

    private var focusDashboard: some View {
        HStack(alignment: .center, spacing: DesignSpace.medium) {
            metricsGrid
            actionsContainer(maxWidth: Constants.focusActionsWidth)
        }
        .padding(DesignSpace.small)
        .fixedSize(horizontal: true, vertical: true)
        .rideNavigationGlassSurface(cornerRadius: Constants.focusCardRadius)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var metricsGrid: some View {
        RideNavigationMetricsRow(state: state)
    }

    @ViewBuilder
    private var activityActions: some View {
        switch state.activity {
        case .preview:
            RideNavigationHorizontalLayout(spacing: DesignSpace.extraSmall) {
                if state.canReverseRoute {
                    actionButton(
                        .rideNavigationReverse,
                        systemImage: "arrow.left.arrow.right",
                        action: onReverse
                    )
                    .rideNavigationSecondaryButton()
                }
                actionButton(
                    previewActionTitle,
                    systemImage: previewActionSystemImage,
                    action: onStart
                )
                .rideNavigationPrimaryButton()
                .disabled(
                    state.isCalculatingRoadRoutes
                        || state.isPreparingTrail
                        || state.routePersistence.isSaving
                )
            }
        case .recording, .paused:
            RideNavigationHorizontalLayout(spacing: DesignSpace.extraSmall) {
                minimizeButton
                actionButton(
                    state.activity == .paused ? .rideNavigationResume : .rideNavigationPause,
                    systemImage: state.activity == .paused ? "play.fill" : "pause.fill",
                    action: onTogglePause
                )
                .rideNavigationSecondaryButton()
                finishButton
            }
        case .following, .navigating:
            RideNavigationHorizontalLayout(spacing: DesignSpace.extraSmall) {
                minimizeButton
                if state.canFindTrailExit {
                    actionButton(
                        state.isFindingTrailExit ? .rideNavigationFindingExit : .rideNavigationGetMeOut,
                        systemImage: "figure.hiking",
                        action: onRequestTrailExit
                    )
                    .rideNavigationSecondaryButton()
                    .disabled(state.isFindingTrailExit)
                }
                if state.canResumeGPX {
                    actionButton(
                        .rideNavigationResumeGPX,
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                        action: onResumeGPX
                    )
                    .rideNavigationSecondaryButton()
                }
                finishButton
            }
        }
    }

    @ViewBuilder
    private func actionsContainer(maxWidth: CGFloat) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal) {
                activityActions
            }
            .scrollIndicators(.visible)
            .frame(maxWidth: maxWidth)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            activityActions
                .frame(maxWidth: maxWidth, alignment: .trailing)
        }
    }

    private var previewActionTitle: LocalizedStringResource {
        if state.isPreparingTrail || state.routePersistence.isSaving { return .rideNavigationPreparing }
        if case .failed = state.routePersistence { return .rideNavigationRetrySave }
        return .rideNavigationStart
    }

    private var previewActionSystemImage: String {
        if state.isPreparingTrail || state.routePersistence.isSaving { return "clock" }
        if case .failed = state.routePersistence { return "arrow.clockwise" }
        return "location.north.fill"
    }

    private var finishButton: some View {
        actionButton(
            .rideNavigationFinish,
            systemImage: "stop.fill",
            iconSpacing: Constants.primaryActionIconSpacing,
            action: onRequestFinish
        )
            .tint(DesignColor.critical)
            .foregroundStyle(.white)
            .rideNavigationPrimaryButton()
    }

    private var minimizeButton: some View {
        actionButton(
            .rideNavigationMini,
            systemImage: "arrow.down.right.and.arrow.up.left",
            iconSpacing: Constants.primaryActionIconSpacing,
            action: onMinimize
        )
        .rideNavigationSecondaryButton()
        .disabled(!state.canMinimize)
        .accessibilityLabel(.rideNavigationMinimizeAccessibility)
        .accessibilityIdentifier("rideNavigation.minimize")
    }

    private func actionButton(
        _ title: LocalizedStringResource,
        systemImage: String,
        iconSpacing: CGFloat? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let iconSpacing {
                    HStack(spacing: iconSpacing) {
                        Image(systemName: systemImage)
                        Text(title)
                    }
                } else {
                    Label(title, systemImage: systemImage)
                }
            }
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .controlSize(.large)
    }

    private var isFocusDriving: Bool {
        isFocus && (state.activity == .following || state.activity == .navigating)
    }

    private enum Constants {
        static let dashboardHeight: CGFloat = 76
        static let dashboardRadius: CGFloat = 24
        static let standardActionsWidth: CGFloat = 440
        static let focusCardRadius: CGFloat = 20
        static let focusActionsWidth: CGFloat = 360
        static let primaryActionIconSpacing: CGFloat = 4
    }
}
