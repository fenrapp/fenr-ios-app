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
    func inaccurateLocationsDoNotCreateARecordedRoute() {
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

        #expect(recorder.snapshot(at: start).route == nil)
        #expect(recorder.finish(at: start.addingTimeInterval(10)) == nil)
        #expect(recorder.phase == .finished)
    }

    @Test
    func oneAcceptedPointCreatesARecordedRoute() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let acceptedPoint = point(latitude: 41, longitude: 2, date: start)
        var recorder = RideRouteRecorder()
        recorder.start(at: start)
        recorder.append(acceptedPoint)

        let route = recorder.finish(at: start.addingTimeInterval(10))
        let finishedRoute = try #require(route)

        #expect(finishedRoute.segments.count == 1)
        #expect(finishedRoute.points == [acceptedPoint])
        #expect(recorder.phase == .finished)
    }

    @Test
    func staleAcceptedPointAndLifecycleDatesRemainMonotonic() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let currentPoint = point(latitude: 41, longitude: 2, date: start.addingTimeInterval(10))
        let stalePoint = point(latitude: 41.001, longitude: 2, date: start.addingTimeInterval(5))
        var recorder = RideRouteRecorder()
        recorder.start(at: start)
        recorder.append(currentPoint)
        recorder.append(stalePoint)

        let recordingSnapshot = recorder.snapshot(at: start.addingTimeInterval(5))
        let recordingRoute = try #require(recordingSnapshot.route)
        #expect(recordingRoute.points == [currentPoint, stalePoint])
        #expect(recordingRoute.updatedAt == start.addingTimeInterval(10))
        #expect(recordingSnapshot.activeElapsedSeconds == 10)

        recorder.pause(at: start.addingTimeInterval(7))
        let pausedSnapshot = recorder.snapshot(at: start.addingTimeInterval(7))
        #expect(pausedSnapshot.route?.updatedAt == start.addingTimeInterval(10))
        #expect(pausedSnapshot.activeElapsedSeconds == 10)

        recorder.resume(at: start.addingTimeInterval(8))
        #expect(recorder.snapshot(at: start.addingTimeInterval(8)).activeElapsedSeconds == 10)

        let route = recorder.finish(at: start.addingTimeInterval(9))
        let finishedRoute = try #require(route)
        #expect(finishedRoute.updatedAt == start.addingTimeInterval(10))
        #expect(recorder.snapshot(at: start.addingTimeInterval(9)).activeElapsedSeconds == 10)
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

        let coordinates = route.segments.flatMap(\.points).map(\.coordinate)
        #expect((RideRouteGeometry.closestDistanceMeters(from: midpoint, to: coordinates) ?? 100) < 1)
    }

    private func point(latitude: Double, longitude: Double, date: Date) -> RideRoutePoint {
        RideRoutePoint(
            coordinate: GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)!,
            timestamp: date,
            horizontalAccuracyMeters: 5
        )
    }
}
