public struct RideTripStatistics: Equatable, Sendable {
    public let tripCount: Int
    public let totalDistanceKilometers: Double
    public let totalElapsedSeconds: Double
    public let averageSpeedKilometersPerHour: Double
    public let maximumSpeedKilometersPerHour: Double

    public init(
        tripCount: Int = .zero,
        totalDistanceKilometers: Double = .zero,
        totalElapsedSeconds: Double = .zero,
        averageSpeedKilometersPerHour: Double = .zero,
        maximumSpeedKilometersPerHour: Double = .zero
    ) {
        self.tripCount = tripCount
        self.totalDistanceKilometers = totalDistanceKilometers
        self.totalElapsedSeconds = totalElapsedSeconds
        self.averageSpeedKilometersPerHour = averageSpeedKilometersPerHour
        self.maximumSpeedKilometersPerHour = maximumSpeedKilometersPerHour
    }
}
