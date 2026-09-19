public struct NavigationMapViewport: Equatable, Sendable {
    public let center: NavigationMapCoordinate
    public let visibleHeightMeters: Double
    public let bearingDegrees: Double

    public init?(center: NavigationMapCoordinate, visibleHeightMeters: Double, bearingDegrees: Double) {
        guard visibleHeightMeters.isFinite, visibleHeightMeters > 0, bearingDegrees.isFinite else { return nil }
        self.center = center
        self.visibleHeightMeters = visibleHeightMeters
        self.bearingDegrees = bearingDegrees
    }
}
