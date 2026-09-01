import EnvironmentDomain
import Foundation
import RideNavigationDomain
import Testing

@Suite("Ride route")
struct RideRouteTests {
    @Test("Renaming cannot move route metadata backwards")
    func renamingIsMonotonic() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let updatedAt = createdAt.addingTimeInterval(20)
        let route = RideRoute(
            name: "Original",
            createdAt: createdAt,
            updatedAt: updatedAt,
            segments: []
        )

        let staleRename = route.renamed("Stale", at: createdAt.addingTimeInterval(10))
        let currentRename = staleRename.renamed("Current", at: createdAt.addingTimeInterval(30))

        #expect(staleRename.name == "Stale")
        #expect(staleRename.updatedAt == updatedAt)
        #expect(currentRename.name == "Current")
        #expect(currentRename.updatedAt == createdAt.addingTimeInterval(30))
    }

    @Test("Distance does not bridge separate route segments")
    func distanceDoesNotBridgeSegments() {
        let route = RideRoute(
            name: "Separate segments",
            createdAt: .distantPast,
            segments: [
                RideRouteSegment(points: [
                    point(latitude: 41, longitude: 2),
                    point(latitude: 41.001, longitude: 2)
                ]),
                RideRouteSegment(points: [
                    point(latitude: 42, longitude: 3),
                    point(latitude: 42.001, longitude: 3)
                ])
            ]
        )

        #expect(route.distanceMeters > 200)
        #expect(route.distanceMeters < 300)
    }

    @Test("Reversal preserves route and segment identity while reversing geometry")
    func reversalPreservesIdentityAndMetadata() {
        let routeID = UUID()
        let firstSegmentID = UUID()
        let secondSegmentID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let updatedAt = createdAt.addingTimeInterval(20)
        let firstSegment = RideRouteSegment(
            id: firstSegmentID,
            points: [
                point(latitude: 41, longitude: 2, elevation: 10, timestamp: createdAt),
                point(latitude: 41.001, longitude: 2, elevation: 20, timestamp: updatedAt)
            ]
        )
        let secondSegment = RideRouteSegment(
            id: secondSegmentID,
            points: [
                point(latitude: 42, longitude: 3, elevation: 30, timestamp: createdAt),
                point(latitude: 42.001, longitude: 3, elevation: 40, timestamp: updatedAt)
            ]
        )
        let route = RideRoute(
            id: routeID,
            name: "Original",
            createdAt: createdAt,
            updatedAt: updatedAt,
            segments: [firstSegment, secondSegment]
        )

        let reversed = route.reversed

        #expect(reversed.id == routeID)
        #expect(reversed.name == route.name)
        #expect(reversed.createdAt == createdAt)
        #expect(reversed.updatedAt == updatedAt)
        #expect(reversed.segments.map(\.id) == [secondSegmentID, firstSegmentID])
        #expect(reversed.segments[0].points == Array(secondSegment.points.reversed()))
        #expect(reversed.segments[1].points == Array(firstSegment.points.reversed()))
    }

    private func point(
        latitude: Double,
        longitude: Double,
        elevation: Double? = nil,
        timestamp: Date? = nil
    ) -> RideRoutePoint {
        RideRoutePoint(
            coordinate: GeographicCoordinate(
                latitudeDegrees: latitude,
                longitudeDegrees: longitude
            )!,
            elevationMeters: elevation,
            timestamp: timestamp,
            horizontalAccuracyMeters: 5
        )
    }
}
