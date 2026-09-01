public struct RideNavigationTrailMapPlan: Sendable {
    struct CompletionChunk: Sendable {
        let id: String
        let points: [NavigationMapCoordinate]
        let distancesMeters: [Double]

        var lowerBoundMeters: Double { distancesMeters.first ?? .zero }
        var upperBoundMeters: Double { distancesMeters.last ?? .zero }
    }

    let routeSegments: [[NavigationMapCoordinate]]
    let overviewCoordinates: [NavigationMapCoordinate]
    let startCoordinate: NavigationMapCoordinate
    let finishCoordinate: NavigationMapCoordinate
    let distanceMeters: Double
    let completionChunks: [CompletionChunk]
}
