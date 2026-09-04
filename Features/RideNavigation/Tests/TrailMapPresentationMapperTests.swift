import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import Testing

@MainActor
struct TrailMapPresentationMapperTests {
    @Test("an absent selected route produces no trail overlay")
    func emptyOverlayWithoutSelectedRoute() {
        let overlay = makeMapper().trailOverlay(
            .init(
                hasSelectedRoute: false,
                activity: .preview,
                isPresentingTrailExit: false,
                trailMap: makeTrailMapSnapshot(),
                guidancePlan: nil,
                guidance: makeGuidanceSnapshot()
            )
        )

        #expect(overlay == .empty)
    }

    @Test("preview maps planned segments, endpoints, direction, and bounded indicators")
    func previewOverlayPreservesRoutePresentation() async throws {
        let route = makeLongRoute()
        let plan = try #require(
            await DefaultRideRouteGuidancePlanner(
                entryClassifier: RideRouteEntryClassifier()
            ).makePlan(
                for: route,
                direction: .reverse
            )
        )
        let start = mapCoordinate(route.segments[0].points[1].coordinate)
        let finish = mapCoordinate(route.segments[0].points[0].coordinate)
        let snapshot = makeTrailMapSnapshot(
            segments: [[start, finish], [start]],
            start: start,
            finish: finish,
            revision: 17
        )

        let overlay = makeMapper().trailOverlay(
            .init(
                hasSelectedRoute: true,
                activity: .preview,
                isPresentingTrailExit: false,
                trailMap: snapshot,
                guidancePlan: plan,
                guidance: nil
            )
        )

        #expect(overlay.polylines.map(\.id) == ["planned-0"])
        #expect(overlay.polylines.map(\.role) == [.planned])
        #expect(overlay.polylines.map(\.revision) == [17])
        #expect(overlay.markers.map(\.id) == ["start", "finish"])
        #expect(overlay.markers.map(\.role) == [.start, .finish])
        #expect(!overlay.directionalIndicators.isEmpty)
        #expect(overlay.directionalIndicators.count <= 24)
        #expect(abs((overlay.directionalIndicators.first?.rotationDegrees ?? 0) - 180) < 1)
    }

    @Test("following orders future, completed, partial, and active route geometry")
    func followingOverlayPreservesGeometryOrderAndRevision() throws {
        let first = mapCoordinate(latitude: 41, longitude: 2)
        let second = mapCoordinate(latitude: 41.001, longitude: 2)
        let third = mapCoordinate(latitude: 41.002, longitude: 2)
        let completed = NavigationMapPolyline(
            id: "trail-completed-23-0-0",
            points: [first, second],
            role: .trailCompleted,
            revision: 8
        )
        let partial = NavigationMapPolyline(
            id: "trail-completed-23-0-1",
            points: [second, third],
            role: .trailCompleted,
            revision: 9
        )
        let snapshot = makeTrailMapSnapshot(
            segments: [[first, second], [second, third]],
            start: first,
            finish: third,
            revision: 23,
            completed: [completed, partial]
        )
        let guidance = makeGuidanceSnapshot()
        let mapper = makeMapper()

        let overlay = mapper.trailOverlay(
            .init(
                hasSelectedRoute: true,
                activity: .following,
                isPresentingTrailExit: false,
                trailMap: snapshot,
                guidancePlan: nil,
                guidance: guidance
            )
        )

        #expect(overlay.polylines.map(\.id) == [
            "planned-0",
            "planned-1",
            completed.id,
            partial.id,
            "trail-active-4-0"
        ])
        #expect(overlay.polylines.map(\.role) == [
            .trailFuture,
            .trailFuture,
            .trailCompleted,
            .trailCompleted,
            .trailActive
        ])
        #expect(overlay.polylines.prefix(2).allSatisfy { $0.revision == 23 })
        #expect(overlay.markers.map(\.id) == ["finish"])
        #expect(overlay.directionalIndicators.map(\.id) == ["decision-1"])
        #expect(overlay.directionalIndicators.map(\.rotationDegrees) == [42])
        expectActiveRevisionChanges(
            mapper: mapper,
            snapshot: snapshot,
            guidance: guidance,
            overlay: overlay
        )
    }

    private func expectActiveRevisionChanges(
        mapper: RideNavigationMapPresentationMapper,
        snapshot: RideNavigationTrailMapController.PresentationSnapshot,
        guidance: RideRouteGuidanceSnapshot,
        overlay: RideNavigationMapPresentationMapper.TrailOverlay
    ) {
        let revised = makeTrailMapSnapshot(
            segments: snapshot.segments,
            start: snapshot.startCoordinate,
            finish: snapshot.finishCoordinate,
            revision: snapshot.revision + 1,
            completed: snapshot.completedPolylines
        )
        let revisedOverlay = mapper.trailOverlay(
            .init(
                hasSelectedRoute: true,
                activity: .following,
                isPresentingTrailExit: false,
                trailMap: revised,
                guidancePlan: nil,
                guidance: guidance
            )
        )
        #expect(overlay.polylines.last?.id == revisedOverlay.polylines.last?.id)
        #expect(overlay.polylines.last?.revision != revisedOverlay.polylines.last?.revision)
    }

    @Test("trail exit renders the cached route without following overlays")
    func trailExitOverlayUsesCompletedRoute() {
        let snapshot = makeTrailMapSnapshot()

        let overlay = makeMapper().trailOverlay(
            .init(
                hasSelectedRoute: true,
                activity: .following,
                isPresentingTrailExit: true,
                trailMap: snapshot,
                guidancePlan: nil,
                guidance: makeGuidanceSnapshot()
            )
        )

        #expect(overlay.polylines.map(\.id) == ["planned-0"])
        #expect(overlay.polylines.map(\.role) == [.completed])
        #expect(overlay.polylines.map(\.revision) == [7])
        #expect(overlay.markers.map(\.id) == ["finish"])
        #expect(overlay.markers.map(\.role) == [.finish])
        #expect(overlay.directionalIndicators.map(\.id) == ["decision-1"])
        #expect(overlay.directionalIndicators.map(\.rotationDegrees) == [42])
    }

    private func makeMapper() -> RideNavigationMapPresentationMapper {
        RideNavigationMapPresentationMapper()
    }

    private func makeTrailMapSnapshot(
        segments: [[NavigationMapCoordinate]]? = nil,
        start: NavigationMapCoordinate? = nil,
        finish: NavigationMapCoordinate? = nil,
        revision: Int = 7,
        completed: [NavigationMapPolyline] = []
    ) -> RideNavigationTrailMapController.PresentationSnapshot {
        let defaultStart = mapCoordinate(latitude: 41, longitude: 2)
        let defaultFinish = mapCoordinate(latitude: 41.001, longitude: 2)
        return RideNavigationTrailMapController.PresentationSnapshot(
            segments: segments ?? [[defaultStart, defaultFinish]],
            startCoordinate: start ?? defaultStart,
            finishCoordinate: finish ?? defaultFinish,
            revision: revision,
            completedPolylines: completed
        )
    }

    private func makeGuidanceSnapshot() -> RideRouteGuidanceSnapshot {
        let first = domainCoordinate(latitude: 41, longitude: 2)
        let second = domainCoordinate(latitude: 41.001, longitude: 2)
        return RideRouteGuidanceSnapshot(
            projection: RideRouteProjection(
                coordinate: first,
                position: RideRoutePathPosition(
                    segmentIndex: 4,
                    edgeIndex: 0,
                    fraction: 0,
                    distanceAlongRouteMeters: 10
                ),
                distanceFromRouteMeters: 2,
                localBearingDegrees: 0,
                confidence: .high
            ),
            completedRange: .init(lowerBoundMeters: 0, upperBoundMeters: 10),
            activeCorridorRange: .init(lowerBoundMeters: 10, upperBoundMeters: 20),
            futureRange: .init(lowerBoundMeters: 20, upperBoundMeters: 30),
            activeCorridorSlices: [
                RideRouteGuidanceSlice(
                    segmentIndex: 4,
                    distanceRange: .init(lowerBoundMeters: 10, upperBoundMeters: 20),
                    coordinates: [first, second]
                )
            ],
            directionalIndicators: [
                RideRouteGuidanceIndicator(
                    id: "decision-1",
                    coordinate: second,
                    bearingDegrees: 42
                )
            ],
            decision: nil,
            routeState: .onRoute,
            hasReachedFinish: false
        )
    }

    private func makeLongRoute() -> RideRoute {
        let start = domainCoordinate(latitude: 41, longitude: 2)
        let finish = domainCoordinate(latitude: 41.1, longitude: 2)
        return RideRoute(
            name: "Long trail",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            segments: [
                RideRouteSegment(points: [
                    RideRoutePoint(coordinate: start),
                    RideRoutePoint(coordinate: finish)
                ])
            ]
        )
    }

    private func mapCoordinate(_ coordinate: GeographicCoordinate) -> NavigationMapCoordinate {
        mapCoordinate(
            latitude: coordinate.latitudeDegrees,
            longitude: coordinate.longitudeDegrees
        )
    }

    private func mapCoordinate(latitude: Double, longitude: Double) -> NavigationMapCoordinate {
        NavigationMapCoordinate(
            latitudeDegrees: latitude,
            longitudeDegrees: longitude
        )!
    }

    private func domainCoordinate(latitude: Double, longitude: Double) -> GeographicCoordinate {
        GeographicCoordinate(
            latitudeDegrees: latitude,
            longitudeDegrees: longitude
        )!
    }
}
