import Foundation
import RideSessionDomain

public struct RideTripRecordMapper: Sendable {
    public init() {}

    func makeRecord(from trip: RideTrip) -> RideTripRecord {
        let identity = storedIdentity(trip.vehicleIdentity)
        let record = RideTripRecord(
            id: trip.id,
            vehicleIdentityKind: identity.kind,
            vehicleIdentityValue: identity.value,
            applicationSessionID: trip.applicationSessionID,
            startedAt: trip.startedAt,
            updatedAt: trip.updatedAt
        )
        update(record, from: trip)
        return record
    }

    func update(_ record: RideTripRecord, from trip: RideTrip) {
        let identity = storedIdentity(trip.vehicleIdentity)
        record.vehicleIdentityKind = identity.kind
        record.vehicleIdentityValue = identity.value
        record.applicationSessionID = trip.applicationSessionID
        record.startedAt = trip.startedAt
        record.updatedAt = trip.updatedAt
        record.endedAt = trip.endedAt
        record.startingOdometerKilometers = trip.startingOdometerKilometers
        record.distanceKilometers = trip.distanceKilometers
        record.elapsedSeconds = trip.elapsedSeconds
        record.averageSpeedKilometersPerHour = trip.averageSpeedKilometersPerHour
        record.maximumSpeedKilometersPerHour = trip.maximumSpeedKilometersPerHour
        record.accumulatedSpeedKilometersPerHourSeconds = trip.accumulatedSpeedKilometersPerHourSeconds
        record.speedSampleDurationSeconds = trip.speedSampleDurationSeconds
        record.lastSpeedKilometersPerHour = trip.lastSpeedKilometersPerHour
        record.pausedAt = trip.pausedAt
        record.accumulatedPausedSeconds = trip.accumulatedPausedSeconds
        record.isAwaitingOdometerRebase = trip.isAwaitingOdometerRebase
        record.consumedEnergyWattHours = trip.consumedEnergyWattHours
        record.recoveredEnergyWattHours = trip.recoveredEnergyWattHours
        record.electricalObservedSeconds = trip.electricalObservedSeconds
        record.electricalExpectedSeconds = trip.electricalExpectedSeconds
        record.maximumDischargePowerWatts = trip.maximumDischargePowerWatts
        record.maximumRegenerationPowerWatts = trip.maximumRegenerationPowerWatts
        record.lastElectricalPowerWatts = trip.lastElectricalPowerWatts
        record.lastElectricalSampleAt = trip.lastElectricalSampleAt
        record.isAwaitingElectricalRebase = trip.isAwaitingElectricalRebase
        record.minimumAltitudeMeters = trip.minimumAltitudeMeters
        record.maximumAltitudeMeters = trip.maximumAltitudeMeters
        record.maximumLeftLeanDegrees = trip.maximumLeftLeanDegrees
        record.maximumRightLeanDegrees = trip.maximumRightLeanDegrees
        record.maximumUphillPitchDegrees = trip.maximumUphillPitchDegrees
        record.maximumDownhillPitchDegrees = trip.maximumDownhillPitchDegrees
        record.attitudeSourceRawValue = trip.attitudeSource.rawValue
    }

    func mapToDomain(_ record: RideTripRecord) -> RideTrip? {
        guard let vehicleIdentity = vehicleIdentity(record) else { return nil }
        return RideTrip(
            id: record.id,
            vehicleIdentity: vehicleIdentity,
            applicationSessionID: record.applicationSessionID,
            startedAt: record.startedAt,
            updatedAt: record.updatedAt,
            endedAt: record.endedAt,
            startingOdometerKilometers: record.startingOdometerKilometers,
            distanceKilometers: record.distanceKilometers,
            elapsedSeconds: record.elapsedSeconds,
            averageSpeedKilometersPerHour: record.averageSpeedKilometersPerHour,
            maximumSpeedKilometersPerHour: record.maximumSpeedKilometersPerHour,
            accumulatedSpeedKilometersPerHourSeconds: record.accumulatedSpeedKilometersPerHourSeconds,
            speedSampleDurationSeconds: record.speedSampleDurationSeconds,
            lastSpeedKilometersPerHour: record.lastSpeedKilometersPerHour,
            pausedAt: record.pausedAt,
            accumulatedPausedSeconds: record.accumulatedPausedSeconds,
            isAwaitingOdometerRebase: record.isAwaitingOdometerRebase,
            consumedEnergyWattHours: record.consumedEnergyWattHours,
            recoveredEnergyWattHours: record.recoveredEnergyWattHours,
            electricalObservedSeconds: record.electricalObservedSeconds,
            electricalExpectedSeconds: record.electricalExpectedSeconds,
            maximumDischargePowerWatts: record.maximumDischargePowerWatts,
            maximumRegenerationPowerWatts: record.maximumRegenerationPowerWatts,
            lastElectricalPowerWatts: record.lastElectricalPowerWatts,
            lastElectricalSampleAt: record.lastElectricalSampleAt,
            isAwaitingElectricalRebase: record.isAwaitingElectricalRebase,
            maximumLeftLeanDegrees: record.maximumLeftLeanDegrees,
            maximumRightLeanDegrees: record.maximumRightLeanDegrees,
            maximumUphillPitchDegrees: record.maximumUphillPitchDegrees,
            maximumDownhillPitchDegrees: record.maximumDownhillPitchDegrees,
            minimumAltitudeMeters: record.minimumAltitudeMeters,
            maximumAltitudeMeters: record.maximumAltitudeMeters,
            attitudeSource: record.attitudeSourceRawValue
                .flatMap(RideAttitudeSource.init(rawValue:))
                ?? .legacyPhone
        )
    }

    private func storedIdentity(_ identity: RideVehicleIdentity) -> (kind: String, value: String) {
        switch identity {
        case .temporary(let id): (Constants.temporaryKind, id.uuidString)
        case .vin(let vin): (Constants.vinKind, vin)
        }
    }

    private func vehicleIdentity(_ record: RideTripRecord) -> RideVehicleIdentity? {
        switch record.vehicleIdentityKind {
        case Constants.temporaryKind:
            UUID(uuidString: record.vehicleIdentityValue).map(RideVehicleIdentity.temporary)
        case Constants.vinKind:
            record.vehicleIdentityValue.isEmpty ? nil : .vin(record.vehicleIdentityValue)
        default:
            nil
        }
    }

    enum Constants {
        static let temporaryKind = "temporary"
        static let vinKind = "vin"
    }
}
