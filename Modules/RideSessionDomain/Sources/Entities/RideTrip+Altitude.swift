import Foundation

public extension RideTrip {
    func updatingAltitude(meters: Double?) -> Self {
        guard endedAt == nil, !isPaused, let meters, meters.isFinite else { return self }
        return copy(
            minimumAltitudeMeters: min(minimumAltitudeMeters ?? meters, meters),
            maximumAltitudeMeters: max(maximumAltitudeMeters ?? meters, meters)
        )
    }
}
