import DesignSystem
import SwiftUI
struct RideNavigationMapOverlay: View {
    let state: RideNavigationViewState
    let showsControls: Bool
    let onInteraction: () -> Void
    let onClose: () -> Void
    let onStart: () -> Void
    let onTogglePause: () -> Void
    let onFinish: () -> Void
    let onMinimize: () -> Void
    let onReverse: () -> Void
    let onSelectRouteOption: (Int) -> Void
    let onAvoidTolls: (Bool) -> Void
    let onAvoidHighways: (Bool) -> Void
    let onRecenter: () -> Void
    let onOverview: () -> Void
    let onMapHeadingUp: (Bool) -> Void
    let onToggleVoice: () -> Void
    let onMapStyle: (String) -> Void
    @Binding var activeMapSelector: RideNavigationMapSelector?
    let onFindTrailExit: () -> Void
    let onCancelTrailExit: () -> Void
    let onStartTrailExit: () -> Void
    let onResumeGPX: () -> Void
    let onKeepRidingWithIncomingDestination: () -> Void
    let onEndRideAndOpenIncomingDestination: () -> Void
    @State private var showsFinishConfirmation = false
    @State private var showsTrailExitConfirmation = false

    var body: some View {
        ZStack {
            ZStack {
                if activeMapSelector != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { activeMapSelector = nil }
                }

                VStack(spacing: DesignSpace.small) {
                    if showsControls {
                        topControls
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(1)
                        RideNavigationRoutePlanningOptionsView(
                            state: state,
                            onSelectRouteOption: onSelectRouteOption,
                            onAvoidTolls: onAvoidTolls,
                            onAvoidHighways: onAvoidHighways
                        )
                            .transition(.opacity)
                    }
                    guidance
                    trailExitPreview
                    Spacer(minLength: DesignSpace.medium)
                    if showsControls {
                        bottomDashboard
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        RideNavigationCompactDashboard(state: state)
                            .transition(.scale(scale: Constants.compactTransitionScale).combined(with: .opacity))
                    }
                }
                .zIndex(1)

                RideNavigationMapSelectorPanel(
                    state: state,
                    onMapStyle: { styleID in perform { onMapStyle(styleID) } },
                    onMapHeadingUp: { isHeadingUp in perform { onMapHeadingUp(isHeadingUp) } },
                    activeSelector: $activeMapSelector
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, Constants.controlSize + DesignSpace.small)
                    .transition(
                        .scale(scale: Constants.mapSelectorTransitionScale, anchor: .topTrailing)
                            .combined(with: .opacity)
                    )
                    .zIndex(2)
            }
            .padding(DesignSpace.medium)

            if showsFinishConfirmation {
                RideNavigationFinishConfirmationOverlay(
                    activity: state.activity,
                    isMonochrome: isFocus,
                    onCancel: dismissFinishConfirmation,
                    onConfirm: confirmFinish
                )
                    .ignoresSafeArea()
                    .transition(.opacity.combined(with: .scale(scale: Constants.confirmationTransitionScale)))
                    .zIndex(3)
            }
        }
        .animation(.smooth(duration: Constants.mapSelectorTransitionDuration), value: activeMapSelector)
        .animation(.smooth(duration: Constants.confirmationTransitionDuration), value: showsFinishConfirmation)
        .confirmationDialog(
            "Find a road-accessible exit?",
            isPresented: $showsTrailExitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Find Exit", action: onFindTrailExit)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("FENR will look for a place reachable by road. This is not a rescue service.")
        }
        .confirmationDialog(
            "Open \(state.incomingDestinationTitle ?? "shared destination")?",
            isPresented: incomingDestinationPrompt,
            titleVisibility: .visible
        ) {
            Button("End & Open", role: .destructive, action: onEndRideAndOpenIncomingDestination)
            Button("Keep Riding", action: onKeepRidingWithIncomingDestination)
        } message: {
            Text("A destination was shared with FENR while this ride is active.")
        }
    }
}
private extension RideNavigationMapOverlay {
    private var topControls: some View {
        HStack(alignment: .top, spacing: DesignSpace.small) {
            routeHeader
            Spacer(minLength: DesignSpace.medium)
            mapControlGroup
        }
    }
    private var routeHeader: some View {
        HStack(spacing: DesignSpace.small) {
            Button(
                action: { perform(handleClose) },
                label: { RideNavigationMapControlLabel(systemImage: "xmark") }
            )
            .buttonStyle(.plain)
            .accessibilityLabel(state.activity == .preview ? "Close route" : "End ride")

            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                HStack(spacing: DesignSpace.extraSmall) {
                    if state.activity == .recording || state.activity == .paused {
                        Circle()
                            .fill(state.activity == .paused ? DesignColor.warning : DesignColor.critical)
                            .frame(width: Constants.recordingIndicatorSize, height: Constants.recordingIndicatorSize)
                    }
                    Text(state.routeTitle ?? activityTitle)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                }
                Text("\(state.distanceText) · \(state.elapsedText)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, DesignSpace.medium)
            .frame(minWidth: Constants.routeHeaderMinimumWidth, alignment: .leading)
        }
        .frame(height: Constants.controlSize)
        .rideNavigationGlassSurface(cornerRadius: Constants.controlRadius)
    }
    private var mapControlGroup: some View {
        RideNavigationMapControls(
            state: state,
            onToggleVoice: { perform(onToggleVoice) },
            onOverview: { perform(onOverview) },
            onRecenter: { perform(onRecenter) },
            activeSelector: $activeMapSelector
        )
    }

    @ViewBuilder
    private var guidance: some View {
        if state.isRerouting {
            HStack(spacing: DesignSpace.small) {
                ProgressView()
                    .controlSize(.small)
                Text("REROUTING")
                    .font(.headline.weight(.semibold))
            }
            .padding(.horizontal, DesignSpace.medium)
            .frame(minHeight: Constants.guidanceHeight)
            .rideNavigationGlassSurface(cornerRadius: Constants.guidanceRadius)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let guidance = state.guidance {
            HStack(spacing: DesignSpace.small) {
                Image(systemName: guidance.systemImage)
                    .font(.headline)
                    .rotationEffect(.degrees(guidance.rotationDegrees))
                    .animation(.smooth, value: guidance.rotationDegrees)
                    .foregroundStyle(
                        isFocus
                            ? Color.white
                            : (guidance.emphasis == .warning ? DesignColor.warning : DesignColor.accent)
                    )
                VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                    Text(guidance.text)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    if let detail = guidance.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: .zero)
            }
            .padding(.horizontal, DesignSpace.medium)
            .frame(width: Constants.guidanceWidth)
            .frame(minHeight: Constants.guidanceHeight)
            .rideNavigationGlassSurface(cornerRadius: Constants.guidanceRadius)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bottomDashboard: some View {
        HStack(spacing: DesignSpace.medium) {
            RideNavigationMetric(value: state.speedText, unit: state.speedUnit, label: "Speed")
            metricDivider
            RideNavigationMetric(value: state.modeText, unit: "", label: "Power")
            metricDivider
            RideNavigationMetric(value: state.batteryText, unit: "", label: "Bike")
            metricDivider
            RideNavigationMetric(value: state.elapsedText, unit: "", label: "Time")
            Spacer(minLength: DesignSpace.small)
            activityActions
        }
        .padding(.horizontal, DesignSpace.medium)
        .padding(.vertical, DesignSpace.small)
        .frame(minHeight: Constants.dashboardHeight)
        .rideNavigationGlassSurface(cornerRadius: Constants.dashboardRadius)
    }

    private var metricDivider: some View {
        Divider()
            .frame(height: Constants.metricDividerHeight)
    }

    @ViewBuilder
    private var activityActions: some View {
        switch state.activity {
        case .preview:
            if state.canReverseRoute {
                Button(action: onReverse) {
                    actionLabel("Reverse", systemImage: "arrow.left.arrow.right")
                }
                .controlSize(.large)
                .rideNavigationSecondaryButton()
            }
            Button(action: onStart) {
                actionLabel("Start", systemImage: "location.north.fill")
            }
            .controlSize(.large)
            .rideNavigationPrimaryButton()
            .disabled(state.isCalculatingRoadRoutes)
        case .recording, .paused:
            minimizeButton
            Button(action: onTogglePause) {
                actionLabel(
                    state.activity == .paused ? "Resume" : "Pause",
                    systemImage: state.activity == .paused ? "play.fill" : "pause.fill"
                )
            }
            .controlSize(.large)
            .rideNavigationSecondaryButton()
            finishButton
        case .following, .navigating:
            minimizeButton
            if state.canFindTrailExit {
                Button(
                    action: { perform { showsTrailExitConfirmation = true } },
                    label: {
                        actionLabel(
                            state.isFindingTrailExit ? "Finding Exit…" : "Get Me Out",
                            systemImage: "figure.hiking"
                        )
                    }
                )
                .controlSize(.large)
                .rideNavigationSecondaryButton()
                .disabled(state.isFindingTrailExit)
            }
            if state.canResumeGPX {
                Button(
                    action: { perform(onResumeGPX) },
                    label: {
                        actionLabel(
                            "Resume GPX",
                            systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                        )
                    }
                )
                .controlSize(.large)
                .rideNavigationSecondaryButton()
            }
            finishButton
        }
    }

    private var finishButton: some View {
        Button(
            action: { perform { showsFinishConfirmation = true } },
            label: { actionLabel("Finish", systemImage: "stop.fill") }
        )
        .controlSize(.large)
        .tint(isFocus ? Color.white.opacity(Constants.focusActionOpacity) : DesignColor.critical)
        .rideNavigationPrimaryButton()
    }

    private var minimizeButton: some View {
        Button(
            action: { perform(onMinimize) },
            label: {
                actionLabel("Mini", systemImage: "arrow.down.right.and.arrow.up.left")
            }
        )
        .controlSize(.large)
        .rideNavigationSecondaryButton()
        .disabled(!state.canMinimize)
        .accessibilityLabel("Minimize navigation")
        .accessibilityIdentifier("rideNavigation.minimize")
    }

    @ViewBuilder
    private var trailExitPreview: some View {
        if let preview = state.trailExitPreview {
            RideNavigationTrailExitPreviewCard(
                preview: preview,
                onCancel: onCancelTrailExit,
                onStart: onStartTrailExit
            )
        }
    }

    private var incomingDestinationPrompt: Binding<Bool> {
        Binding(
            get: { state.showsIncomingDestinationPrompt },
            set: { value in
                if !value { onKeepRidingWithIncomingDestination() }
            }
        )
    }

    private var isFocus: Bool {
        state.mapScene.displayStyle == .focus
    }

    private func dismissFinishConfirmation() {
        perform { showsFinishConfirmation = false }
    }

    private func confirmFinish() {
        perform {
            showsFinishConfirmation = false
            onFinish()
        }
    }

    private func handleClose() {
        if state.activity == .preview {
            onClose()
        } else {
            showsFinishConfirmation = true
        }
    }

    private func perform(_ action: () -> Void) {
        onInteraction()
        action()
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var activityTitle: String {
        switch state.activity {
        case .recording, .paused: "Recording Ride"
        case .navigating: "Navigation"
        case .following: "Enduro Navigation"
        case .preview: "Route Preview"
        }
    }

    private enum Constants {
        static let controlSize: CGFloat = 48
        static let controlRadius: CGFloat = 24
        static let recordingIndicatorSize: CGFloat = 8
        static let routeHeaderMinimumWidth: CGFloat = 220
        static let guidanceWidth: CGFloat = 360
        static let guidanceHeight: CGFloat = 52
        static let guidanceRadius: CGFloat = 18
        static let dashboardHeight: CGFloat = 76
        static let dashboardRadius: CGFloat = 24
        static let metricDividerHeight: CGFloat = 32
        static let focusActionOpacity = 0.88
        static let compactTransitionScale = 0.96
        static let mapSelectorTransitionScale = 0.94
        static let mapSelectorTransitionDuration = 0.2
        static let confirmationTransitionScale = 0.96
        static let confirmationTransitionDuration = 0.2
    }
}
