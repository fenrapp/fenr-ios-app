import CoreGraphics
import MapKit
import RideNavigation
@testable import RideNavigationAppleMaps
import Testing

struct AppleNavigationMapCameraRenderStateTests {
    @Test("active trail corridor renders above every other route layer")
    func activeTrailRenderPriority() {
        let otherRoles: [NavigationMapPolylineRole] = [
            .planned,
            .trailCompleted,
            .trailFuture,
            .completed,
            .recorded,
            .approach,
            .rejoinGuide
        ]

        #expect(otherRoles.allSatisfy { $0.renderPriority < NavigationMapPolylineRole.trailActive.renderPriority })
    }

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

    @Test("Focus icons and cached paths use the same map projection")
    func focusProjectionMatchesPathTransform() throws {
        let north = try #require(
            NavigationMapCoordinate(latitudeDegrees: 60, longitudeDegrees: 2)
        )
        let south = try #require(
            NavigationMapCoordinate(latitudeDegrees: 30, longitudeDegrees: 2)
        )
        let scene = NavigationMapScene(userCoordinate: north)
        let viewport = FocusNavigationViewport(
            scene: scene,
            camera: .overview([south, north]),
            size: CGSize(width: 800, height: 400)
        )
        let mapPoint = MKMapPoint(north.clCoordinate)
        let expected = CGPoint(x: mapPoint.x, y: mapPoint.y).applying(viewport.mapTransform)
        let actual = viewport.point(for: north)

        #expect(abs(actual.x - expected.x) < 0.001)
        #expect(abs(actual.y - expected.y) < 0.001)
    }
}
