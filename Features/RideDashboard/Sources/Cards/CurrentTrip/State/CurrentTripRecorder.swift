import BikeDomain
import Foundation
import RideSessionDomain

struct CurrentTripRecorder {
    let applicationSessionID: UUID
    private(set) var trip: RideTrip?

    init(applicationSessionID: UUID, trip: RideTrip? = nil) {
        self.applicationSessionID = applicationSessionID
        self.trip = trip
    }

    mutating func restore(_ trip: RideTrip?) {
        guard trip?.applicationSessionID == applicationSessionID else { return }
        self.trip = trip
    }

    @discardableResult
    mutating func record(
        runState: BikeRunState,
        at date: Date,
        odometerKilometers: Double?,
        speedKilometersPerHour: Double?
    ) -> RideTrip? {
        if trip == nil {
            guard runState.startsCurrentTrip else { return nil }
            trip = RideTrip(
                applicationSessionID: applicationSessionID,
                startedAt: date,
                startingOdometerKilometers: odometerKilometers,
                maximumSpeedKilometersPerHour: max(speedKilometersPerHour ?? .zero, .zero)
            )
        }
        trip = trip?.updating(
            at: date,
            odometerKilometers: odometerKilometers,
            speedKilometersPerHour: speedKilometersPerHour
        )
        return trip
    }

    @discardableResult
    mutating func tick(
        at date: Date,
        speedKilometersPerHour: Double?
    ) -> RideTrip? {
        guard let trip else { return nil }
        self.trip = trip.updating(
            at: date,
            odometerKilometers: nil,
            speedKilometersPerHour: speedKilometersPerHour
        )
        return self.trip
    }

    @discardableResult
    mutating func pause(
        at date: Date,
        odometerKilometers: Double?,
        speedKilometersPerHour: Double?
    ) -> RideTrip? {
        guard let trip, !trip.isPaused else { return self.trip }
        self.trip = trip.updating(
            at: date,
            odometerKilometers: odometerKilometers,
            speedKilometersPerHour: speedKilometersPerHour
        ).paused(at: date)
        return self.trip
    }

    @discardableResult
    mutating func resume(
        at date: Date,
        odometerKilometers: Double?,
        speedKilometersPerHour: Double?
    ) -> RideTrip? {
        guard let trip, trip.isPaused else { return self.trip }
        self.trip = trip.resumed(
            at: date,
            odometerKilometers: odometerKilometers,
            speedKilometersPerHour: speedKilometersPerHour
        )
        return self.trip
    }

    @discardableResult
    mutating func clear() -> RideTrip? {
        defer { trip = nil }
        return trip
    }
}

private extension BikeRunState {
    var startsCurrentTrip: Bool {
        switch self {
        case .on, .crawlForward, .crawlReverse:
            true
        case .unknown, .off, .neutral, .charging:
            false
        }
    }
}
