@testable import RideNavigation
import Testing

struct RideNavigationPresentationModelsTests {
    @Test("map scene keeps directional indicators and compatible defaults")
    func mapSceneDirectionalIndicatorDefaults() throws {
        let coordinate = try #require(
            NavigationMapCoordinate(latitudeDegrees: 41, longitudeDegrees: 2)
        )
        let indicator = NavigationMapDirectionalIndicator(
            id: "trail-chevron-1",
            coordinate: coordinate,
            rotationDegrees: 92
        )

        #expect(NavigationMapScene().directionalIndicators.isEmpty)
        #expect(NavigationMapScene(directionalIndicators: [indicator]).directionalIndicators == [indicator])
    }

    @Test("route persistence exposes only an active save as saving")
    func routePersistenceSavingState() {
        #expect(RideNavigationRoutePersistenceState.saving.isSaving)
        #expect(!RideNavigationRoutePersistenceState.idle.isSaving)
        #expect(!RideNavigationRoutePersistenceState.saved.isSaving)
        #expect(!RideNavigationRoutePersistenceState.failed(message: "Unavailable").isSaving)
    }

    @Test("mini state preserves fork and arrival guidance")
    func miniStateGuidance() {
        let fork = RideNavigationForkGuidance(
            instructionText: "KEEP RIGHT",
            distanceText: "80 m",
            systemImage: "arrow.turn.up.right"
        )
        let state = RideNavigationMiniViewState(
            forkGuidance: fork,
            isArrivalPending: true
        )

        #expect(state.forkGuidance == fork)
        #expect(state.isArrivalPending)
    }

    @Test("polyline fallback revision includes intermediate geometry")
    func polylineGeometryRevision() throws {
        let start = try #require(NavigationMapCoordinate(latitudeDegrees: 41, longitudeDegrees: 2))
        let finish = try #require(NavigationMapCoordinate(latitudeDegrees: 42, longitudeDegrees: 3))
        let firstMiddle = try #require(
            NavigationMapCoordinate(latitudeDegrees: 41.25, longitudeDegrees: 2.25)
        )
        let secondMiddle = try #require(
            NavigationMapCoordinate(latitudeDegrees: 41.75, longitudeDegrees: 2.75)
        )
        let first = NavigationMapPolyline(
            id: "road-route",
            points: [start, firstMiddle, finish],
            role: .approach
        )
        let second = NavigationMapPolyline(
            id: "road-route",
            points: [start, secondMiddle, finish],
            role: .approach
        )

        #expect(first.revision != second.revision)
    }
}
