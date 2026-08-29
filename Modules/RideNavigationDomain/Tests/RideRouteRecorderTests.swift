import EnvironmentDomain
import Foundation
@testable import RideNavigationDomain
import Testing

struct RideRouteRecorderTests {
    @Test
    func pauseAndResumeCreateSeparateTrackSegmentsAndExcludePausedTime() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        var recorder = RideRouteRecorder()
        recorder.start(at: start, name: "Test ride")
        recorder.append(point(latitude: 41.0, longitude: 2.0, date: start))
        recorder.append(point(latitude: 41.001, longitude: 2.0, date: start.addingTimeInterval(10)))
        recorder.pause(at: start.addingTimeInterval(20))
        recorder.resume(at: start.addingTimeInterval(120))
        recorder.append(point(latitude: 41.002, longitude: 2.0, date: start.addingTimeInterval(125)))

        let snapshot = recorder.snapshot(at: start.addingTimeInterval(130))
        let route = try #require(snapshot.route)

        #expect(route.segments.count == 2)
        #expect(snapshot.activeElapsedSeconds == 30)
    }

    @Test
    func inaccurateLocationsAreIgnored() {
        let start = Date(timeIntervalSince1970: 1_000)
        var recorder = RideRouteRecorder()
        recorder.start(at: start)
        recorder.append(
            RideRoutePoint(
                coordinate: GeographicCoordinate(latitudeDegrees: 41, longitudeDegrees: 2)!,
                timestamp: start,
                horizontalAccuracyMeters: 80
            )
        )

        #expect(recorder.snapshot(at: start).route?.points.isEmpty == true)
    }

    @Test
    func closestDistanceUsesTrackSegmentsBetweenSparsePoints() {
        let date = Date(timeIntervalSince1970: 1_000)
        let route = RideRoute(
            name: "Sparse route",
            createdAt: date,
            segments: [
                RideRouteSegment(points: [
                    point(latitude: 41, longitude: 2, date: date),
                    point(latitude: 41, longitude: 2.02, date: date)
                ])
            ]
        )
        let midpoint = GeographicCoordinate(latitudeDegrees: 41, longitudeDegrees: 2.01)!

        #expect((RideRouteGeometry.closestDistanceMeters(from: midpoint, to: route) ?? 100) < 1)
    }

    private func point(latitude: Double, longitude: Double, date: Date) -> RideRoutePoint {
        RideRoutePoint(
            coordinate: GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!,
            timestamp: date,
            horizontalAccuracyMeters: 5
        )
    }
}
