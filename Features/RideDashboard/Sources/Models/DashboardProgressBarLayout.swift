public struct DashboardProgressBarLayout: Equatable, Sendable {
    public let trackHeight: Double
    public let energyHeight: Double
    public let centerMarkerWidth: Double

    public static let regular = Self(trackHeight: 3, energyHeight: 7, centerMarkerWidth: 2)

    public init(trackHeight: Double, energyHeight: Double, centerMarkerWidth: Double) {
        self.trackHeight = trackHeight
        self.energyHeight = energyHeight
        self.centerMarkerWidth = centerMarkerWidth
    }
}
