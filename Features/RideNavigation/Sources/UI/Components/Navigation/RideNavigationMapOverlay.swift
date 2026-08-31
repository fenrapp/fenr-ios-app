import DesignSystem
import SwiftUI
struct RideNavigationMapOverlay: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
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
            navigationOverlay
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
    private var navigationOverlay: some View {
        ZStack {
            if !dynamicTypeSize.isAccessibilitySize, activeMapSelector != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { activeMapSelector = nil }
            }
            VStack(spacing: DesignSpace.small) {
                if showsControls {
                    topControls
                        .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                        .layoutPriority(dynamicTypeSize.isAccessibilitySize ? 2 : 0)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
                if dynamicTypeSize.isAccessibilitySize {
                    accessibilityMiddle
                } else {
                    if showsControls {
                        planningOptions
                            .transition(.opacity)
                    }
                    guidance
                    trailExitPreview
                    Spacer(minLength: DesignSpace.medium)
                }
                if !usesCompactAccessibilityLayout { bottomContent }
            }
            .zIndex(1)
            if !dynamicTypeSize.isAccessibilitySize {
                mapSelectorPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, RideNavigationTopControls.height + DesignSpace.small)
                    .zIndex(2)
            }
        }
        .padding(DesignSpace.medium)
    }
    @ViewBuilder
    private var accessibilityMiddle: some View {
        if hasAccessibilityMiddleContent || usesCompactAccessibilityLayout {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: DesignSpace.small) {
                    if activeMapSelector != nil {
                        mapSelectorPanel
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    if showsControls {
                        planningOptions
                            .transition(.opacity)
                    }
                    guidance
                    trailExitPreview
                    if usesCompactAccessibilityLayout { compactBottomContent }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.visible)
            .id(usesCompactAccessibilityLayout && state.activity == .paused)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
        } else {
            Spacer(minLength: DesignSpace.medium)
        }
    }
    private var topControls: some View {
        RideNavigationTopControls(
            state: state,
            activeMapSelector: $activeMapSelector,
            onClose: { perform(handleClose) },
            onToggleVoice: { perform(onToggleVoice) },
            onOverview: { perform(onOverview) },
            onRecenter: { perform(onRecenter) }
        )
    }
    private var planningOptions: some View {
        RideNavigationRoutePlanningOptionsView(
            state: state,
            onSelectRouteOption: onSelectRouteOption,
            onAvoidTolls: onAvoidTolls,
            onAvoidHighways: onAvoidHighways
        )
    }
    private var mapSelectorPanel: some View {
        RideNavigationMapSelectorPanel(
            state: state,
            onMapStyle: { styleID in perform { onMapStyle(styleID) } },
            onMapHeadingUp: { isHeadingUp in perform { onMapHeadingUp(isHeadingUp) } },
            activeSelector: $activeMapSelector
        )
        .transition(.scale(scale: Constants.mapSelectorTransitionScale, anchor: .topTrailing)
            .combined(with: .opacity))
    }
    @ViewBuilder
    private var bottomContent: some View {
        if showsControls {
            bottomDashboard
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            RideNavigationCompactDashboard(state: state)
                .transition(.scale(scale: Constants.compactTransitionScale).combined(with: .opacity))
        }
    }
    private var hasAccessibilityMiddleContent: Bool { activeMapSelector != nil
        || (showsControls && hasPlanningOptions) || state.isRerouting
        || state.guidance != nil || state.trailExitPreview != nil }
    private var usesCompactAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize
        && verticalSizeClass == .compact }
    private var hasPlanningOptions: Bool { (state.activity == .preview
        && state.roadRouteOptions.count > 1) || state.showsRoadRoutePreferences }
    @ViewBuilder
    private var guidance: some View {
        if state.isRerouting {
            HStack(spacing: DesignSpace.small) {
                ProgressView()
                    .controlSize(.small)
                Text("REROUTING")
                    .font(.headline.weight(.semibold))
            }
            .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
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
                    .foregroundStyle(isFocus ? Color.white : guidance.emphasis == .warning
                        ? DesignColor.warning : DesignColor.accent)
                VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                    Text(guidance.text)
                        .font(.headline.weight(.semibold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    if let detail = guidance.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    }
                }
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                Spacer(minLength: .zero)
            }
            .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            .padding(.horizontal, DesignSpace.medium)
            .frame(maxWidth: usesCompactAccessibilityLayout ? .infinity : Constants.guidanceWidth)
            .frame(minHeight: Constants.guidanceHeight)
            .rideNavigationGlassSurface(cornerRadius: Constants.guidanceRadius)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var bottomDashboard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignSpace.medium) {
                dashboardMetrics
                Spacer(minLength: DesignSpace.small)
                activityActions
            }
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSpace.small) {
                    dashboardMetrics
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
    @ViewBuilder
    private var compactBottomContent: some View {
        if showsControls {
            VStack(alignment: .leading, spacing: DesignSpace.small) {
                dashboardMetrics; activityActions
            }
            .padding(.horizontal, DesignSpace.medium)
            .padding(.vertical, DesignSpace.small)
            .frame(minHeight: Constants.dashboardHeight)
            .rideNavigationGlassSurface(cornerRadius: Constants.dashboardRadius)
        } else {
            RideNavigationCompactDashboard(state: state)
        }
    }
    @ViewBuilder
    private var dashboardMetrics: some View {
        RideNavigationMetric(value: state.speedText, unit: state.speedUnit, label: "Speed")
        metricDivider
        RideNavigationMetric(value: state.modeText, unit: "", label: "Power")
        metricDivider
        RideNavigationMetric(value: state.batteryText, unit: "", label: "Bike")
        metricDivider
        RideNavigationMetric(value: state.elapsedText, unit: "", label: "Time")
    }
    private var metricDivider: some View { Divider().frame(height: Constants.metricDividerHeight) }
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
        Binding(get: { state.showsIncomingDestinationPrompt },
                set: { if !$0 { onKeepRidingWithIncomingDestination() } })
    }
    private var isFocus: Bool { state.mapScene.displayStyle == .focus }
    private func dismissFinishConfirmation() { perform { showsFinishConfirmation = false } }
    private func confirmFinish() {
        perform {
            showsFinishConfirmation = false
            onFinish()
        }
    }
    private func handleClose() {
        if state.activity == .preview { onClose() } else { showsFinishConfirmation = true }
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
    private enum Constants {
        static let guidanceWidth: CGFloat = 360, guidanceHeight: CGFloat = 52
        static let guidanceRadius: CGFloat = 18, dashboardHeight: CGFloat = 76
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
