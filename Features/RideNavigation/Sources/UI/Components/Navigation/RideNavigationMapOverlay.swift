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
    let onSelectTrailDirection: (RideNavigationTrailDirection) -> Void
    let onCancelTrailDirectionSelection: () -> Void
    let onFinishAfterArrival: () -> Void
    let onKeepRidingAfterArrival: () -> Void
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
    private let guidanceVisibilityPolicy = RideNavigationGuidanceVisibilityPolicy()
    @State private var showsTrailExitConfirmation = false
    var body: some View {
        ZStack {
            navigationOverlay
            if showsFinishConfirmation {
                RideNavigationFinishConfirmationOverlay(
                    activity: state.activity,
                    onCancel: dismissFinishConfirmation,
                    onConfirm: confirmFinish
                )
                    .ignoresSafeArea()
                    .transition(.opacity.combined(with: .scale(scale: Constants.confirmationTransitionScale)))
                    .zIndex(3)
            }
            if let arrivalPrompt = state.arrivalPrompt {
                RideNavigationFinishConfirmationOverlay(
                    activity: state.activity,
                    arrivalPrompt: arrivalPrompt,
                    onCancel: onKeepRidingAfterArrival,
                    onConfirm: onFinishAfterArrival
                )
                .ignoresSafeArea()
                .transition(.opacity.combined(with: .scale(scale: Constants.confirmationTransitionScale)))
                .zIndex(4)
            }
        }
        .animation(.smooth(duration: Constants.mapSelectorTransitionDuration), value: activeMapSelector)
        .animation(.smooth(duration: Constants.confirmationTransitionDuration), value: showsFinishConfirmation)
        .confirmationDialog(
            .rideNavigationFindRoadExitQuestion,
            isPresented: $showsTrailExitConfirmation,
            titleVisibility: .visible
        ) {
            Button(.rideNavigationFindExit, action: onFindTrailExit)
            Button(.rideNavigationCancel, role: .cancel) {}
        } message: {
            Text(.rideNavigationFindRoadExitDetail)
        }
        .confirmationDialog(
            .rideNavigationOpenIncomingDestination(
                state.incomingDestinationTitle ?? String(localized: .rideNavigationSharedDestination)
            ),
            isPresented: incomingDestinationPrompt,
            titleVisibility: .visible
        ) {
            Button(.rideNavigationEndAndOpen, role: .destructive, action: onEndRideAndOpenIncomingDestination)
            Button(.rideNavigationKeepRiding, action: onKeepRidingWithIncomingDestination)
        } message: {
            Text(.rideNavigationIncomingDestinationDetail)
        }
        .confirmationDialog(
            state.trailEntryPrompt?.title ?? String(localized: .rideNavigationChooseRouteDirection),
            isPresented: trailEntryPrompt,
            titleVisibility: .visible
        ) {
            if state.trailEntryPrompt?.availableDirections.contains(.forward) == true {
                Button(.rideNavigationFollowForward) { onSelectTrailDirection(.forward) }
            }
            if state.trailEntryPrompt?.availableDirections.contains(.reverse) == true {
                Button(.rideNavigationFollowInReverse) { onSelectTrailDirection(.reverse) }
            }
            Button(.rideNavigationCancel, role: .cancel, action: onCancelTrailDirectionSelection)
        } message: {
            Text(state.trailEntryPrompt?.detail ?? String(localized: .rideNavigationSelectDirectionDetail))
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
                    standardMiddle
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
    private var standardMiddle: some View {
        RideNavigationMapMiddleRegion(
            hasContent: hasStandardMiddleContent,
            showsScrollIndicators: false
        ) {
            standardMiddleContent
        }
    }

    private var standardMiddleContent: some View {
        VStack(alignment: .leading, spacing: DesignSpace.small) {
            guidance
            forkGuidance
            trailExitPreview
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    private var accessibilityMiddle: some View {
        RideNavigationMapMiddleRegion(
            hasContent: hasAccessibilityMiddleContent || usesCompactAccessibilityLayout,
            showsScrollIndicators: true
        ) {
            accessibilityMiddleContent
        }
        .id(usesCompactAccessibilityLayout && state.activity == .paused)
    }

    private var accessibilityMiddleContent: some View {
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
            forkGuidance
            trailExitPreview
            if usesCompactAccessibilityLayout { compactBottomContent }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
    private var topControls: some View {
        RideNavigationTopControls(
            state: state,
            activeMapSelector: $activeMapSelector,
            onClose: { perform(handleClose) },
            onToggleVoice: { perform(onToggleVoice) },
            onOverview: { perform(onOverview) },
            onRecenter: { perform(onRecenter) },
            onMapHeadingUp: { isHeadingUp in perform { onMapHeadingUp(isHeadingUp) } }
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
                .allowsHitTesting(false)
                .transition(.scale(scale: Constants.compactTransitionScale).combined(with: .opacity))
        }
    }
    private var hasAccessibilityMiddleContent: Bool { activeMapSelector != nil
        || (showsControls && hasPlanningOptions) || state.isRerouting
        || state.guidance != nil || state.forkGuidance != nil || state.trailExitPreview != nil }
    private var hasStandardMiddleContent: Bool {
        if shouldShowGuidance || state.trailExitPreview != nil { return true }
        guard let forkGuidance = state.forkGuidance else { return false }
        return shouldShowForkGuidance(forkGuidance)
    }
    private var usesCompactAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize
        && verticalSizeClass == .compact }
    private var hasPlanningOptions: Bool { (state.activity == .preview
        && state.roadRouteOptions.count > 1) || state.showsRoadRoutePreferences }
    @ViewBuilder
    private var guidance: some View {
        if shouldShowGuidance {
            RideNavigationGuidanceCard(
                state: state,
                isMonochrome: isFocus
            )
            .allowsHitTesting(false)
        }
    }
    @ViewBuilder
    private var forkGuidance: some View {
        if let forkGuidance = state.forkGuidance,
           shouldShowForkGuidance(forkGuidance) {
            RideNavigationForkGuidanceCard(
                guidance: forkGuidance,
                isMonochrome: isFocus
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
        }
    }
    private var bottomDashboard: some View {
        RideNavigationActivityDashboard(
            state: state,
            isFocus: isFocus,
            onStart: onStart,
            onTogglePause: onTogglePause,
            onMinimize: onMinimize,
            onReverse: onReverse,
            onRequestTrailExit: { perform { showsTrailExitConfirmation = true } },
            onResumeGPX: { perform(onResumeGPX) },
            onRequestFinish: { perform { showsFinishConfirmation = true } }
        )
    }
    @ViewBuilder
    private var compactBottomContent: some View {
        if showsControls {
            bottomDashboard
        } else {
            RideNavigationCompactDashboard(state: state)
                .allowsHitTesting(false)
        }
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
    private var trailEntryPrompt: Binding<Bool> {
        Binding(
            get: { state.trailEntryPrompt != nil },
            set: { if !$0 { onCancelTrailDirectionSelection() } }
        )
    }
    private var isFocus: Bool { state.mapScene.displayStyle == .focus }
    private var shouldShowGuidance: Bool {
        guidanceVisibilityPolicy.showsGuidance(
            isFocus: isFocus,
            showsGuidanceInFocus: state.showsGuidanceInFocus,
            isRerouting: state.isRerouting,
            guidance: state.guidance
        )
    }
    private func shouldShowForkGuidance(_ guidance: RideNavigationForkGuidance) -> Bool {
        guidanceVisibilityPolicy.showsForkGuidance(
            isFocus: isFocus,
            showsGuidanceInFocus: state.showsGuidanceInFocus,
            guidance: guidance
        )
    }
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
    private enum Constants {
        static let compactTransitionScale = 0.96
        static let mapSelectorTransitionScale = 0.94
        static let mapSelectorTransitionDuration = 0.2
        static let confirmationTransitionScale = 0.96
        static let confirmationTransitionDuration = 0.2
    }
}
