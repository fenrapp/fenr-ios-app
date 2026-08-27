import RideSessionDomain

public struct RideEnergyBucketRecordMapper: Sendable {
    public init() {}

    func makeRecord(from bucket: RideEnergyBucket, trip: RideTrip) -> RideEnergyBucketRecord {
        let identity = storedIdentity(trip.vehicleIdentity)
        let record = RideEnergyBucketRecord(
            id: bucket.id,
            tripID: trip.id,
            vehicleIdentityKind: identity.kind,
            vehicleIdentityValue: identity.value,
            applicationSessionID: trip.applicationSessionID,
            startedAt: bucket.startedAt,
            updatedAt: bucket.updatedAt
        )
        update(record, from: bucket, trip: trip)
        return record
    }

    func update(_ record: RideEnergyBucketRecord, from bucket: RideEnergyBucket, trip: RideTrip) {
        let identity = storedIdentity(trip.vehicleIdentity)
        record.tripID = trip.id
        record.vehicleIdentityKind = identity.kind
        record.vehicleIdentityValue = identity.value
        record.applicationSessionID = trip.applicationSessionID
        record.startedAt = bucket.startedAt
        record.updatedAt = bucket.updatedAt
        record.startDistanceKilometers = bucket.startDistanceKilometers
        record.endDistanceKilometers = bucket.endDistanceKilometers
        record.stateOfChargePercent = bucket.stateOfChargePercent
        record.consumedEnergyWattHours = bucket.consumedEnergyWattHours
        record.recoveredEnergyWattHours = bucket.recoveredEnergyWattHours
    }

    func mapToDomain(_ record: RideEnergyBucketRecord) -> RideEnergyBucket {
        RideEnergyBucket(
            id: record.id,
            startedAt: record.startedAt,
            updatedAt: record.updatedAt,
            startDistanceKilometers: record.startDistanceKilometers,
            endDistanceKilometers: record.endDistanceKilometers,
            stateOfChargePercent: record.stateOfChargePercent,
            consumedEnergyWattHours: record.consumedEnergyWattHours,
            recoveredEnergyWattHours: record.recoveredEnergyWattHours
        )
    }

    private func storedIdentity(_ identity: RideVehicleIdentity) -> (kind: String, value: String) {
        switch identity {
        case .temporary(let id): (RideTripRecordMapper.Constants.temporaryKind, id.uuidString)
        case .vin(let vin): (RideTripRecordMapper.Constants.vinKind, vin)
        }
    }
}
