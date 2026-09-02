#if DEBUG
import RideNavigation
import SwiftUI

private struct FocusNavigationMapPreview: View {
    let scene: NavigationMapScene

    var body: some View {
        FocusNavigationMapView(
            scene: scene,
            renderer: FocusNavigationRenderer(pathCache: FocusNavigationPathCache()),
            onIntent: { _ in },
            onInteraction: {}
        )
        .background(Color.black)
        .ignoresSafeArea()
    }
}

private enum FocusNavigationMapPreviewScenes {
    static let follow = NavigationMapScene(
        source: .appleStandard,
        displayStyle: .focus,
        camera: .follow(coordinate: rider, headingDegrees: 38),
        userCoordinate: rider,
        userHeadingDegrees: 38,
        polylines: polylines,
        markers: markers
    )

    static let overview = NavigationMapScene(
        source: .appleStandard,
        displayStyle: .focus,
        camera: .overview(visibleCoordinates),
        userCoordinate: rider,
        userHeadingDegrees: 124,
        polylines: polylines,
        markers: markers
    )

    static let automatic = NavigationMapScene(
        source: .appleStandard,
        displayStyle: .focus,
        camera: .automatic,
        userCoordinate: rider,
        userHeadingDegrees: 286,
        polylines: polylines,
        markers: markers
    )

    private static let start = coordinate(latitude: 40.0000, longitude: -3.0000)
    private static let completedEnd = coordinate(latitude: 40.0018, longitude: -2.9978)
    private static let rider = coordinate(latitude: 40.0036, longitude: -2.9951)
    private static let plannedTurn = coordinate(latitude: 40.0058, longitude: -2.9916)
    private static let finish = coordinate(latitude: 40.0080, longitude: -2.9880)
    private static let participant = coordinate(latitude: 40.0044, longitude: -2.9990)
    private static let rejoin = coordinate(latitude: 40.0066, longitude: -2.9930)

    private static let visibleCoordinates = [
        start,
        completedEnd,
        rider,
        plannedTurn,
        finish,
        participant,
        rejoin
    ]

    private static let polylines = [
        NavigationMapPolyline(
            id: "preview.planned",
            points: [rider, plannedTurn, finish],
            role: .planned
        ),
        NavigationMapPolyline(
            id: "preview.completed",
            points: [start, completedEnd, rider],
            role: .completed
        ),
        NavigationMapPolyline(
            id: "preview.recorded",
            points: [start, participant, rider],
            role: .recorded
        ),
        NavigationMapPolyline(
            id: "preview.approach",
            points: [plannedTurn, finish],
            role: .approach
        ),
        NavigationMapPolyline(
            id: "preview.rejoin",
            points: [rider, rejoin, plannedTurn],
            role: .rejoinGuide
        )
    ]

    private static let markers = [
        NavigationMapMarker(
            id: "preview.start",
            coordinate: start,
            title: "Start",
            role: .start
        ),
        NavigationMapMarker(
            id: "preview.finish",
            coordinate: finish,
            title: "Finish",
            role: .finish
        ),
        NavigationMapMarker(
            id: "preview.waypoint",
            coordinate: plannedTurn,
            title: "Waypoint",
            role: .waypoint
        ),
        NavigationMapMarker(
            id: "preview.participant",
            coordinate: participant,
            title: "Participant",
            role: .participant
        )
    ]

    private static func coordinate(
        latitude: Double,
        longitude: Double
    ) -> NavigationMapCoordinate {
        guard let coordinate = NavigationMapCoordinate(
            latitudeDegrees: latitude,
            longitudeDegrees: longitude
        ) else {
            preconditionFailure("Invalid Focus map preview coordinate")
        }
        return coordinate
    }
}

#Preview("Focus Map · Follow", traits: .landscapeLeft) {
    FocusNavigationMapPreview(scene: FocusNavigationMapPreviewScenes.follow)
}

#Preview("Focus Map · Overview", traits: .landscapeLeft) {
    FocusNavigationMapPreview(scene: FocusNavigationMapPreviewScenes.overview)
}

#Preview("Focus Map · Automatic", traits: .landscapeLeft) {
    FocusNavigationMapPreview(scene: FocusNavigationMapPreviewScenes.automatic)
}
#endif
