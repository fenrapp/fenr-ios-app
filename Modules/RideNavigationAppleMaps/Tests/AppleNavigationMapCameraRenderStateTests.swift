import RideNavigation
@testable import RideNavigationAppleMaps
import Testing

struct AppleNavigationMapCameraRenderStateTests {
    @Test("automatic camera rendering changes when a location first arrives")
    func automaticCameraStateChangesWhenLocationArrives() throws {
        let initial = AppleNavigationMapCameraRenderState(scene: NavigationMapScene())
        let coordinate = try #require(
            NavigationMapCoordinate(latitudeDegrees: 41, longitudeDegrees: 2)
        )
        let updated = AppleNavigationMapCameraRenderState(
            scene: NavigationMapScene(userCoordinate: coordinate)
        )

        #expect(initial != updated)
        #expect(initial.userCoordinate == nil)
        #expect(updated.userCoordinate == coordinate)
    }

    @Test("automatic camera rendering changes when the location moves")
    func automaticCameraStateChangesWhenLocationMoves() throws {
        let firstCoordinate = try #require(
            NavigationMapCoordinate(latitudeDegrees: 41, longitudeDegrees: 2)
        )
        let secondCoordinate = try #require(
            NavigationMapCoordinate(latitudeDegrees: 41.1, longitudeDegrees: 2.1)
        )
        let first = AppleNavigationMapCameraRenderState(
            scene: NavigationMapScene(userCoordinate: firstCoordinate)
        )
        let second = AppleNavigationMapCameraRenderState(
            scene: NavigationMapScene(userCoordinate: secondCoordinate)
        )

        #expect(first != second)
        #expect(second.userCoordinate == secondCoordinate)
    }
}
