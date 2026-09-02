import DesignSystem
import SwiftUI

struct RideNavigationActivityDashboard: View {
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignSpace.medium) {
                standardMetrics
                Spacer(minLength: DesignSpace.small)
                activityActions
            }
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSpace.small) {
                    standardMetrics
                    activityActions
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, DesignSpace.medium)
        .padding(.vertical, DesignSpace.small)
        .frame(minHeight: Constants.dashboardHeight)
        .rideNavigationGlassSurface(cornerRadius: Constants.dashboardRadius)
    }

    private var focusDashboard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: DesignSpace.medium) {
                focusMetrics
                    .padding(DesignSpace.small)
                    .rideNavigationGlassSurface(cornerRadius: Constants.focusCardRadius)
                Spacer(minLength: Constants.focusCenterClearance)
                focusActions
            }
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSpace.small) {
                    focusMetrics
                    Divider()
                    activityActions
                }
                .padding(DesignSpace.small)
                .frame(maxWidth: Constants.focusFallbackWidth, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: Constants.focusFallbackHeight)
            .rideNavigationGlassSurface(cornerRadius: Constants.focusCardRadius)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    private var focusActions: some View {
        ScrollView(.vertical) {
            VStack(alignment: .trailing, spacing: DesignSpace.extraSmall) {
                activityActions
            }
            .padding(DesignSpace.small)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: Constants.focusActionsWidth, maxHeight: Constants.focusActionsHeight)
        .rideNavigationGlassSurface(cornerRadius: Constants.focusCardRadius)
    }

    @ViewBuilder
    private var standardMetrics: some View {
        RideNavigationMetric(value: state.speedText, unit: state.speedUnit, label: .rideNavigationMetricSpeed)
        metricDivider
        RideNavigationMetric(value: state.modeText, unit: "", label: .rideNavigationMetricPower)
        metricDivider
        RideNavigationMetric(value: state.batteryText, unit: "", label: .rideNavigationMetricBike)
        metricDivider
        RideNavigationMetric(value: state.elapsedText, unit: "", label: .rideNavigationMetricTime)
    }

    private var focusMetrics: some View {
        Grid(horizontalSpacing: DesignSpace.medium, verticalSpacing: DesignSpace.small) {
            GridRow {
                RideNavigationMetric(value: state.speedText, unit: state.speedUnit, label: .rideNavigationMetricSpeed)
                RideNavigationMetric(value: state.modeText, unit: "", label: .rideNavigationMetricPower)
            }
            GridRow {
                RideNavigationMetric(value: state.batteryText, unit: "", label: .rideNavigationMetricBike)
                RideNavigationMetric(value: state.elapsedText, unit: "", label: .rideNavigationMetricTime)
            }
        }
        .frame(maxWidth: Constants.focusMetricsWidth)
    }

    private var metricDivider: some View {
        Divider().frame(height: Constants.metricDividerHeight)
    }

    @ViewBuilder
    private var activityActions: some View {
        switch state.activity {
        case .preview:
            if state.canReverseRoute {
                actionButton(.rideNavigationReverse, systemImage: "arrow.left.arrow.right", action: onReverse)
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
        case .recording, .paused:
            minimizeButton
            actionButton(
                state.activity == .paused ? .rideNavigationResume : .rideNavigationPause,
                systemImage: state.activity == .paused ? "play.fill" : "pause.fill",
                action: onTogglePause
            )
            .rideNavigationSecondaryButton()
            finishButton
        case .following, .navigating:
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
        actionButton(.rideNavigationFinish, systemImage: "stop.fill", action: onRequestFinish)
            .tint(isFocus ? Color.white.opacity(Constants.focusActionOpacity) : DesignColor.critical)
            .rideNavigationPrimaryButton()
    }

    private var minimizeButton: some View {
        actionButton(
            .rideNavigationMini,
            systemImage: "arrow.down.right.and.arrow.up.left",
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
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
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
        static let metricDividerHeight: CGFloat = 32
        static let focusActionOpacity = 0.88
        static let focusCardRadius: CGFloat = 20
        static let focusCenterClearance: CGFloat = 24
        static let focusMetricsWidth: CGFloat = 220
        static let focusActionsWidth: CGFloat = 190
        static let focusActionsHeight: CGFloat = 190
        static let focusFallbackWidth: CGFloat = 260
        static let focusFallbackHeight: CGFloat = 280
    }
}
