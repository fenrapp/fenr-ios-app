public struct RideTripStatisticsAggregator: Sendable {
    public init() {}

    public func aggregate(_ trips: [RideTrip]) -> RideTripStatistics {
        var totalDistance = 0.0
        var totalElapsed = 0.0
        var totalSpeedIntegral = 0.0
        var totalSpeedSampleDuration = 0.0
        var maximumSpeed = 0.0

        for trip in trips {
            totalDistance += max(trip.distanceKilometers, .zero)
            totalElapsed += max(trip.elapsedSeconds, .zero)
            maximumSpeed = max(maximumSpeed, trip.maximumSpeedKilometersPerHour)

            let sampleDuration = effectiveSampleDuration(for: trip)
            totalSpeedSampleDuration += sampleDuration
            totalSpeedIntegral += effectiveSpeedIntegral(
                for: trip,
                sampleDuration: sampleDuration
            )
        }

        return RideTripStatistics(
            tripCount: trips.count,
            totalDistanceKilometers: totalDistance,
            totalElapsedSeconds: totalElapsed,
            averageSpeedKilometersPerHour: totalSpeedSampleDuration > .zero
                ? totalSpeedIntegral / totalSpeedSampleDuration
                : .zero,
            maximumSpeedKilometersPerHour: maximumSpeed
        )
    }

    private func effectiveSampleDuration(for trip: RideTrip) -> Double {
        if trip.speedSampleDurationSeconds > .zero {
            return trip.speedSampleDurationSeconds
        }
        return trip.averageSpeedKilometersPerHour > .zero
            ? max(trip.elapsedSeconds, .zero)
            : .zero
    }

    private func effectiveSpeedIntegral(
        for trip: RideTrip,
        sampleDuration: Double
    ) -> Double {
        if trip.speedSampleDurationSeconds > .zero {
            return max(trip.accumulatedSpeedKilometersPerHourSeconds, .zero)
        }
        return max(trip.averageSpeedKilometersPerHour, .zero) * sampleDuration
    }
}
