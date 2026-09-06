import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import Testing

struct RideNavigationTrailMapPreparerTests {
    @Test("precomputes bounded render chunks without bridging GPX segments")
    @MainActor
    func boundedChunksPreserveSegments() async throws {
        let route = makeRoute(pointsPerSegment: 1_200)
        let preparer = RideNavigationTrailMapPreparer(
            mapper: RideNavigationMapPresentationMapper()
        )
        let plan = try #require(await preparer.prepare(route: route, direction: .forward))

        #expect(plan.routeSegments.count == 2)
        #expect(plan.routeSegments.allSatisfy { $0.count == 1_200 })
        #expect(plan.completionChunks.allSatisfy { $0.points.count <= 512 })
        #expect(plan.startCoordinate == plan.routeSegments[0][0])
        #expect(plan.finishCoordinate == plan.routeSegments[1][1_199])

        let controller = RideNavigationTrailMapController()
        controller.apply(plan)
        controller.advanceCompletion(to: plan.distanceMeters * 0.9)
        let completed = controller.presentationSnapshot.completedPolylines

        #expect(!completed.isEmpty)
        #expect(completed.allSatisfy { $0.points.count <= 512 })
        #expect(completed.count <= plan.completionChunks.count)

        let firstChunk = try #require(plan.completionChunks.first)
        controller.resetCompletion()
        controller.advanceCompletion(
            to: (firstChunk.lowerBoundMeters + firstChunk.upperBoundMeters) / 2
        )
        let partial = controller.presentationSnapshot.completedPolylines
        let partialPolyline = try #require(partial.last)
        controller.advanceCompletion(to: firstChunk.upperBoundMeters)
        let full = controller.presentationSnapshot.completedPolylines
        let fullPolyline = try #require(full.first { $0.id == partialPolyline.id })

        #expect(partialPolyline.revision != fullPolyline.revision)
        #expect(fullPolyline.points == firstChunk.points)
    }

    @Test("reverse preparation preserves segment boundaries and orientation")
    func reversePreparation() async throws {
        let route = makeRoute(pointsPerSegment: 3)
        let preparer = RideNavigationTrailMapPreparer(
            mapper: RideNavigationMapPresentationMapper()
        )
        let plan = try #require(await preparer.prepare(route: route, direction: .reverse))
        let expectedStart = route.segments[1].points[2].coordinate
        let expectedFinish = route.segments[0].points[0].coordinate

        #expect(plan.routeSegments.count == 2)
        #expect(plan.startCoordinate.latitudeDegrees == expectedStart.latitudeDegrees)
        #expect(plan.finishCoordinate.latitudeDegrees == expectedFinish.latitudeDegrees)
    }

    @Test("cancellation prevents publishing a render plan")
    func cancellation() async {
        let route = makeRoute(pointsPerSegment: 50_000)
        let preparer = RideNavigationTrailMapPreparer(
            mapper: RideNavigationMapPresentationMapper()
        )
        let task = Task { await preparer.prepare(route: route, direction: .forward) }
        task.cancel()

        #expect(await task.value == nil)
    }

    private func makeRoute(pointsPerSegment: Int) -> RideRoute {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return RideRoute(
            name: "Chunked trail",
            createdAt: date,
            segments: (0 ..< 2).map { segmentIndex in
                RideRouteSegment(points: (0 ..< pointsPerSegment).map { pointIndex in
                    let offset = Double(pointIndex) * 0.000_001
                    return RideRoutePoint(coordinate: GeographicCoordinate(
                        latitudeDegrees: 40 + Double(segmentIndex) + offset,
                        longitudeDegrees: 2 + offset
                    )!)
                })
            }
        )
    }
}
