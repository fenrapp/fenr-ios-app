import BikeDomain
import Foundation
import RideSessionDomain

struct CurrentTripRecorder {
    private(set) var context: BikeSessionContext
    private(set) var trip: RideTrip?

    init(context: BikeSessionContext, trip: RideTrip? = nil) {
        self.context = context
        self.trip = trip
    }

    mutating func restore(_ trip: RideTrip?) {
        guard let trip else {
            self.trip = nil
            return
        }
        guard trip.applicationSessionID == context.applicationSessionID,
              trip.vehicleIdentity == context.vehicleIdentity else { return }
        self.trip = trip
    }

    mutating func promote(to vin: String) {
        context = context.promoting(to: vin)
        trip = trip?.promotingVehicleIdentity(to: vin)
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
                vehicleIdentity: context.vehicleIdentity,
                applicationSessionID: context.applicationSessionID,
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
