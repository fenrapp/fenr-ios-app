import EnvironmentDomain
import RideNavigationDomain

public protocol RideNavigationTrailMapPreparing: Sendable {
    func prepare(
        route: RideRoute,
        direction: RideRouteDirection
    ) async -> RideNavigationTrailMapPlan?
}

public actor RideNavigationTrailMapPreparer: RideNavigationTrailMapPreparing {
    private struct PreparedSegment {
        let coordinates: [NavigationMapCoordinate]
        let chunks: [RideNavigationTrailMapPlan.CompletionChunk]
        let endingDistanceMeters: Double
    }

    private enum Constants {
        static let maximumChunkPointCount = 512
        static let cancellationCheckInterval = 1_024
    }

    private let mapper: RideNavigationMapPresentationMapper

    public init(mapper: RideNavigationMapPresentationMapper) {
        self.mapper = mapper
    }

    public func prepare(
        route: RideRoute,
        direction: RideRouteDirection
    ) async -> RideNavigationTrailMapPlan? {
        var routeSegments: [[NavigationMapCoordinate]] = []
        var overviewCoordinates: [NavigationMapCoordinate] = []
        var completionChunks: [RideNavigationTrailMapPlan.CompletionChunk] = []
        var distanceMeters = 0.0
        var visitedPointCount = 0

        for orientedSegmentIndex in route.segments.indices {
            guard !Task.isCancelled else { return nil }
            let sourceSegmentIndex = direction == .forward
                ? orientedSegmentIndex
                : route.segments.index(before: route.segments.endIndex) - orientedSegmentIndex
            let points = route.segments[sourceSegmentIndex].points
            guard let prepared = prepareSegment(
                points: points,
                isReversed: direction == .reverse,
                segmentIndex: orientedSegmentIndex,
                startingDistanceMeters: distanceMeters,
                visitedPointCount: visitedPointCount
            ) else { return nil }
            routeSegments.append(prepared.coordinates)
            overviewCoordinates.append(contentsOf: prepared.coordinates)
            completionChunks.append(contentsOf: prepared.chunks)
            distanceMeters = prepared.endingDistanceMeters
            visitedPointCount += points.count
        }

        guard let startCoordinate = routeSegments.first(where: { !$0.isEmpty })?.first,
              let finishCoordinate = routeSegments.last(where: { !$0.isEmpty })?.last,
              !completionChunks.isEmpty else { return nil }
        return RideNavigationTrailMapPlan(
            routeSegments: routeSegments,
            overviewCoordinates: overviewCoordinates,
            startCoordinate: startCoordinate,
            finishCoordinate: finishCoordinate,
            distanceMeters: distanceMeters,
            completionChunks: completionChunks
        )
    }

    private func prepareSegment(
        points: [RideRoutePoint],
        isReversed: Bool,
        segmentIndex: Int,
        startingDistanceMeters: Double,
        visitedPointCount: Int
    ) -> PreparedSegment? {
        var segmentCoordinates: [NavigationMapCoordinate] = []
        segmentCoordinates.reserveCapacity(points.count)
        var chunks: [RideNavigationTrailMapPlan.CompletionChunk] = []
        var chunkPoints: [NavigationMapCoordinate] = []
        var chunkDistances: [Double] = []
        var previousCoordinate: GeographicCoordinate?
        var distanceMeters = startingDistanceMeters
        var chunkIndex = 0

        for pointOffset in points.indices {
            if (visitedPointCount + pointOffset)
                .isMultiple(of: Constants.cancellationCheckInterval), Task.isCancelled {
                return nil
            }
            let pointIndex = isReversed
                ? points.index(before: points.endIndex) - pointOffset
                : pointOffset
            let coordinate = points[pointIndex].coordinate
            if let previousCoordinate {
                distanceMeters += RideRouteGeometry.distanceMeters(
                    from: previousCoordinate,
                    to: coordinate
                )
            }
            let mapCoordinate = mapper.coordinate(coordinate)
            segmentCoordinates.append(mapCoordinate)
            chunkPoints.append(mapCoordinate)
            chunkDistances.append(distanceMeters)
            previousCoordinate = coordinate
            guard chunkPoints.count == Constants.maximumChunkPointCount else { continue }
            chunks.append(makeChunk(
                segmentIndex: segmentIndex,
                chunkIndex: chunkIndex,
                points: chunkPoints,
                distancesMeters: chunkDistances
            ))
            chunkIndex += 1
            chunkPoints = [mapCoordinate]
            chunkDistances = [distanceMeters]
        }
        if chunkPoints.count > 1 {
            chunks.append(makeChunk(
                segmentIndex: segmentIndex,
                chunkIndex: chunkIndex,
                points: chunkPoints,
                distancesMeters: chunkDistances
            ))
        }
        return PreparedSegment(
            coordinates: segmentCoordinates,
            chunks: chunks,
            endingDistanceMeters: distanceMeters
        )
    }

    private func makeChunk(
        segmentIndex: Int,
        chunkIndex: Int,
        points: [NavigationMapCoordinate],
        distancesMeters: [Double]
    ) -> RideNavigationTrailMapPlan.CompletionChunk {
        RideNavigationTrailMapPlan.CompletionChunk(
            id: "\(segmentIndex)-\(chunkIndex)",
            points: points,
            distancesMeters: distancesMeters
        )
    }
}
