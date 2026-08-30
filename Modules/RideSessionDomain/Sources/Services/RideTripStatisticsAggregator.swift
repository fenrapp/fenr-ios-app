public struct RideTripStatisticsAggregator: Sendable {
    public init() {}

    public func aggregate(_ trips: [RideTrip]) -> RideTripStatistics {
        var totalDistance = 0.0
        var totalElapsed = 0.0
        var totalSpeedIntegral = 0.0
        var totalSpeedSampleDuration = 0.0
        var maximumSpeed = 0.0

        for trip in trips {
            totalDistance += normalized(trip.distanceKilometers)
            totalElapsed += normalized(trip.elapsedSeconds)
            maximumSpeed = max(maximumSpeed, normalized(trip.maximumSpeedKilometersPerHour))

            let speedObservation = speedObservation(for: trip)
            totalSpeedSampleDuration += speedObservation.duration
            totalSpeedIntegral += speedObservation.integral
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

    private func normalized(_ value: Double) -> Double {
        guard value.isFinite, value >= .zero else { return .zero }
        return value
    }

    private func speedObservation(for trip: RideTrip) -> SpeedObservation {
        let recordedDuration = trip.speedSampleDurationSeconds
        if recordedDuration > .zero {
            guard recordedDuration.isFinite,
                  trip.accumulatedSpeedKilometersPerHourSeconds.isFinite,
                  trip.accumulatedSpeedKilometersPerHourSeconds >= .zero else { return .zero }
            return .init(
                duration: recordedDuration,
                integral: trip.accumulatedSpeedKilometersPerHourSeconds
            )
        }

        guard recordedDuration == .zero,
              trip.elapsedSeconds.isFinite,
              trip.elapsedSeconds >= .zero,
              trip.averageSpeedKilometersPerHour.isFinite,
              trip.averageSpeedKilometersPerHour >= .zero else { return .zero }
        let integral = trip.averageSpeedKilometersPerHour * trip.elapsedSeconds
        guard integral.isFinite else { return .zero }
        return .init(duration: trip.elapsedSeconds, integral: integral)
    }

    private struct SpeedObservation {
        let duration: Double
        let integral: Double

        static let zero = Self(duration: .zero, integral: .zero)
    }
}
