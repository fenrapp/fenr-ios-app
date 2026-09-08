import Foundation
import RideNavigationDomain
import Testing

struct RideRouteRecordingDistanceTests {
    @Test("Distance accumulates only accepted points, including close points accepted by elapsed time")
    func acceptedDistancePreservesPointFilters() throws {
        let first = RecordingDistanceAcceptanceFixture.point(latitude: 41, seconds: 0)
        let earlyNearby = RecordingDistanceAcceptanceFixture.point(latitude: 41.000001, seconds: 2)
        let timedNearby = RecordingDistanceAcceptanceFixture.point(latitude: 41.000001, seconds: 5)
        let distant = RecordingDistanceAcceptanceFixture.point(latitude: 41.001, seconds: 6)
        let inaccurate = RecordingDistanceAcceptanceFixture.point(latitude: 41.01, seconds: 20, accuracy: 51)
        var recorder = RideRouteRecorder()
        recorder.start(at: RecordingDistanceAcceptanceFixture.start)
        recorder.append(first)
        recorder.append(earlyNearby)
        let initial = try #require(recorder.snapshot(at: RecordingDistanceAcceptanceFixture.start).route)
        #expect(initial.points == [first])
        #expect(initial.distanceMeters == 0)

        recorder.append(timedNearby)
        recorder.append(distant)
        recorder.append(inaccurate)
        let final = try #require(recorder.snapshot(at: RecordingDistanceAcceptanceFixture.start).route)
        #expect(final.points == [first, timedNearby, distant])
        let expected = RideRouteGeometry.distanceMeters(along: [first, timedNearby, distant])
        #expect(final.distanceMeters == expected)
    }

    @Test("An hours-long recording preserves incremental distance across snapshots and unconnected paused segments")
    func longRecordingDistanceHasNoPauseBridge() throws {
        var recorder = RideRouteRecorder()
        let start = LongRecordingFixture.start
        recorder.start(at: start, name: "Long ride")
        for index in 0 ..< 4_000 { recorder.append(LongRecordingFixture.point(index)) }
        recorder.pause(at: start.addingTimeInterval(20_000))
        let paused = try #require(recorder.snapshot(at: start.addingTimeInterval(25_000)).route)
        let distanceBeforePause = paused.distanceMeters
        recorder.append(LongRecordingFixture.point(4_000, latitudeOffset: 2))
        #expect(recorder.snapshot(at: start.addingTimeInterval(25_000)).route?.distanceMeters == distanceBeforePause)
        recorder.resume(at: start.addingTimeInterval(25_000))
        for index in 4_000 ..< 10_000 { recorder.append(LongRecordingFixture.point(index, latitudeOffset: 2)) }
        let snapshot = try #require(recorder.snapshot(at: start.addingTimeInterval(50_000)).route)
        #expect(snapshot.points.count == 10_000)
        #expect(snapshot.segments.count == 2)
        let expected = snapshot.segments.reduce(0.0) {
            $0 + RideRouteGeometry.distanceMeters(along: $1.points)
        }
        #expect(abs(snapshot.distanceMeters - expected) < 0.000001)
        let bridged = RideRouteGeometry.distanceMeters(along: snapshot.points)
        #expect(bridged - snapshot.distanceMeters > 200_000)
        for _ in 0 ..< 1_000 {
            let repeated = recorder.snapshot(at: start.addingTimeInterval(50_000))
            #expect(repeated.route?.distanceMeters == snapshot.distanceMeters)
        }
        let finished = recorder.finish(at: start.addingTimeInterval(50_000))
        let completed = try #require(finished)
        #expect(completed.distanceMeters == snapshot.distanceMeters)
        let reconstructed = RideRoute(
            id: completed.id, name: completed.name, createdAt: completed.createdAt,
            updatedAt: completed.updatedAt, segments: completed.segments
        )
        #expect(reconstructed == completed)
        #expect(abs(reconstructed.distanceMeters - completed.distanceMeters) < 0.000001)
        #expect(completed.renamed("Renamed", at: start).distanceMeters == completed.distanceMeters)
        #expect(completed.reversed.distanceMeters == completed.distanceMeters)
        #expect(completed.reversed.reversed == completed)
        recorder.start(at: start.addingTimeInterval(60_000))
        recorder.append(LongRecordingFixture.point(10_001))
        #expect(recorder.snapshot(at: start.addingTimeInterval(60_000)).route?.distanceMeters == 0)
    }
}
