import EnvironmentDomain
import RideNavigationDomain

public struct RideNavigationMapSceneBuilder: Sendable {
    struct RouteTrace: Sendable {
        let idPrefix: String
        let role: NavigationMapPolylineRole
        let segments: [RideRouteSegment]
    }

    struct Input: Sendable {
        let source: MapSourceDescriptor
        let displayStyle: NavigationMapDisplayStyle
        let camera: NavigationMapCamera
        let userCoordinate: GeographicCoordinate?
        let userHeadingDegrees: Double?
        let trailOverlay: RideNavigationMapPresentationMapper.TrailOverlayInput
        let roadRoute: RoadNavigationRoute?
        let roadRouteRevision: Int
        let destination: NavigationPlace?
        let trailExit: TrailExitRoute?
        let trailExitRevision: Int
        let rejoinGuide: [GeographicCoordinate]?
        let traces: [RouteTrace]
    }

    private let mapper: RideNavigationMapPresentationMapper

    public init(mapper: RideNavigationMapPresentationMapper) {
        self.mapper = mapper
    }

    func makeScene(_ input: Input) -> NavigationMapScene {
        let overlay = mapper.trailOverlay(input.trailOverlay)
        var polylines = overlay.polylines
        var markers = overlay.markers
        appendRoadRoute(input, to: &polylines, markers: &markers)
        appendTrailExit(input, to: &polylines, markers: &markers)
        appendRejoinGuide(input.rejoinGuide, to: &polylines)
        input.traces.forEach { appendTrace($0, to: &polylines) }
        return NavigationMapScene(
            source: input.source,
            displayStyle: input.displayStyle,
            camera: input.camera,
            userCoordinate: input.userCoordinate.map(mapper.coordinate),
            userHeadingDegrees: input.userHeadingDegrees,
            polylines: polylines,
            markers: markers,
            directionalIndicators: overlay.directionalIndicators
        )
    }

    func makeMiniScene(
        from scene: NavigationMapScene,
        camera: NavigationMapCamera,
        rejoinGuide: [GeographicCoordinate]?
    ) -> NavigationMapScene {
        var polylines = scene.polylines
        if !polylines.contains(where: { $0.role == .rejoinGuide }) {
            appendRejoinGuide(rejoinGuide, to: &polylines)
        }
        return NavigationMapScene(
            source: scene.source,
            displayStyle: scene.displayStyle,
            camera: camera,
            userCoordinate: scene.userCoordinate,
            userHeadingDegrees: scene.userHeadingDegrees,
            polylines: polylines,
            markers: [],
            directionalIndicators: scene.directionalIndicators
        )
    }

    private func appendRoadRoute(
        _ input: Input,
        to polylines: inout [NavigationMapPolyline],
        markers: inout [NavigationMapMarker]
    ) {
        guard let route = input.roadRoute else { return }
        polylines.append(.init(
            id: "road-route",
            points: mapper.coordinates(route.points),
            role: .approach,
            revision: input.roadRouteRevision
        ))
        if let destination = input.destination {
            markers.append(.init(
                id: "destination",
                coordinate: mapper.coordinate(destination.coordinate),
                title: destination.name,
                role: .finish
            ))
        }
    }

    private func appendTrailExit(
        _ input: Input,
        to polylines: inout [NavigationMapPolyline],
        markers: inout [NavigationMapMarker]
    ) {
        guard let trailExit = input.trailExit else { return }
        polylines.append(.init(
            id: "trail-exit-preview",
            points: mapper.coordinates(trailExit.route.points),
            role: .approach,
            revision: input.trailExitRevision
        ))
        markers.append(.init(
            id: "trail-exit-destination",
            coordinate: mapper.coordinate(trailExit.destination.coordinate),
            title: trailExit.destination.name,
            role: .finish
        ))
    }

    private func appendRejoinGuide(
        _ coordinates: [GeographicCoordinate]?,
        to polylines: inout [NavigationMapPolyline]
    ) {
        guard let coordinates else { return }
        polylines.append(.init(
            id: "trail-rejoin-guide",
            points: mapper.coordinates(coordinates),
            role: .rejoinGuide
        ))
    }

    private func appendTrace(
        _ trace: RouteTrace,
        to polylines: inout [NavigationMapPolyline]
    ) {
        for (index, segment) in trace.segments.enumerated() {
            polylines.append(.init(
                id: "\(trace.idPrefix)-\(index)",
                points: mapper.coordinates(segment.points.map(\.coordinate)),
                role: trace.role,
                revision: segment.points.count
            ))
        }
    }
}
