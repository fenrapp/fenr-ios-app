import SwiftUI

private struct RideNavigationMapPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let state: RideNavigationViewState
    @State private var selector: RideNavigationMapSelector?

    var body: some View {
        RideNavigationMapOverlay(
            state: state,
            showsControls: true,
            onInteraction: {},
            onClose: {},
            onStart: {},
            onTogglePause: {},
            onFinish: {},
            onMinimize: {},
            onReverse: {},
            onSelectTrailDirection: { _ in },
            onCancelTrailDirectionSelection: {},
            onFinishAfterArrival: {},
            onKeepRidingAfterArrival: {},
            onSelectRouteOption: { _ in },
            onAvoidTolls: { _ in },
            onAvoidHighways: { _ in },
            onRecenter: {},
            onOverview: {},
            onMapHeadingUp: { _ in },
            onToggleVoice: {},
            onMapStyle: { _ in },
            activeMapSelector: $selector,
            onFindTrailExit: {},
            onCancelTrailExit: {},
            onStartTrailExit: {},
            onResumeGPX: {},
            onKeepRidingWithIncomingDestination: {},
            onEndRideAndOpenIncomingDestination: {}
        )
        .rideNavigationFocusAppearance(state.mapScene.displayStyle == .focus)
        .background(previewBackground)
    }

    private var previewBackground: Color {
        guard state.mapScene.displayStyle == .focus else { return .black }
        return RideNavigationFocusPalette(colorScheme: colorScheme).background
    }
}

private enum RideNavigationMapPreviewStates {
    static let roadAlternatives = RideNavigationViewState(
        screen: .map,
        activity: .preview,
        speedText: "--",
        speedUnit: "km/h",
        modeText: "ENDURO",
        batteryText: "72%",
        elapsedText: "00:00",
        distanceText: "138.6 km",
        routeTitle: "High mountain crossing with three long road alternatives",
        roadRouteOptions: [
            RideNavigationRoadRouteOption(
                id: 0,
                title: "Fastest route through the valley",
                detail: "124.8 km · 1 hr 42 min · includes toll roads",
                isSelected: false
            ),
            RideNavigationRoadRouteOption(
                id: 1,
                title: "Balanced mountain approach",
                detail: "138.6 km · 2 hr 08 min · avoids highways",
                isSelected: true
            ),
            RideNavigationRoadRouteOption(
                id: 2,
                title: "Scenic route around the national park",
                detail: "164.2 km · 2 hr 51 min · no toll roads",
                isSelected: false
            )
        ],
        avoidsTolls: true,
        avoidsHighways: false,
        showsRoadRoutePreferences: true,
        canReverseRoute: true
    )

    static let rerouting = RideNavigationViewState(
        screen: .map,
        activity: .navigating,
        speedText: "86",
        speedUnit: "km/h",
        modeText: "ENDURO",
        batteryText: "31%",
        elapsedText: "1:47:22",
        distanceText: "96.4 km",
        routeTitle: "Rerouting the high mountain crossing after a missed turn",
        isRerouting: true,
        canMinimize: true
    )

    static let paused = RideNavigationViewState(
        screen: .map,
        activity: .paused,
        speedText: "0",
        speedUnit: "km/h",
        modeText: "ENDURO",
        batteryText: "43%",
        elapsedText: "00:42:18",
        distanceText: "27.5 km",
        guidance: RideNavigationGuidance(
            text: "RECORDING PAUSED",
            systemImage: "pause.circle.fill",
            emphasis: .warning
        ),
        routeTitle: "Recording Ride",
        canMinimize: true
    )

    static let offTrail = RideNavigationViewState(
        screen: .map,
        activity: .following,
        mapScene: NavigationMapScene(displayStyle: .focus),
        selectedMapStyleID: "focus",
        allowsFocusMapStyle: true,
        speedText: "24",
        speedUnit: "km/h",
        modeText: "ENDURO",
        batteryText: "19%",
        elapsedText: "2:14:38",
        distanceText: "128.4 km",
        guidance: RideNavigationGuidance(
            text: "RETURN TO TRAIL",
            detail: "Rejoin the highlighted trail after the next ridge in 1.2 km",
            systemImage: "location.north.fill",
            emphasis: .warning
        ),
        routeTitle: "High mountain crossing with a long destination name",
        canMinimize: true,
        canFindTrailExit: true
    )

    static let trailExit = RideNavigationViewState(
        screen: .map,
        activity: .following,
        speedText: "18",
        speedUnit: "km/h",
        modeText: "ENDURO",
        batteryText: "16%",
        elapsedText: "2:21:04",
        distanceText: "132.1 km",
        routeTitle: "High mountain crossing with a long destination name",
        canMinimize: true,
        canResumeGPX: true,
        trailExitPreview: RideNavigationTrailExitPreview(
            title: "Road-accessible exit near the eastern service track",
            detail: "5.8 km · around 14 min to the nearest paved road"
        )
    )
}

#Preview("Map · Road alternatives · Accessibility", traits: .landscapeLeft) {
    RideNavigationMapPreview(state: RideNavigationMapPreviewStates.roadAlternatives)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Map · Rerouting · Accessibility", traits: .landscapeLeft) {
    RideNavigationMapPreview(state: RideNavigationMapPreviewStates.rerouting)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Map · Paused compact · Accessibility", traits: .landscapeLeft) {
    RideNavigationMapPreview(state: RideNavigationMapPreviewStates.paused)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Map · Off trail · Accessibility", traits: .landscapeLeft) {
    RideNavigationMapPreview(state: RideNavigationMapPreviewStates.offTrail)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Map · Focus · Night", traits: .landscapeLeft) {
    RideNavigationMapPreview(state: RideNavigationMapPreviewStates.offTrail)
        .preferredColorScheme(.dark)
}

#Preview("Map · Focus · Day", traits: .landscapeLeft) {
    RideNavigationMapPreview(state: RideNavigationMapPreviewStates.offTrail)
        .preferredColorScheme(.light)
}

#Preview("Map · Trail exit · Accessibility", traits: .landscapeLeft) {
    RideNavigationMapPreview(state: RideNavigationMapPreviewStates.trailExit)
        .environment(\.dynamicTypeSize, .accessibility3)
}
