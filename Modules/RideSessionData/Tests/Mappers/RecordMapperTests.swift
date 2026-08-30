import Foundation
@testable import RideSessionData
import RideSessionDomain
import Testing

@Suite("Ride trip persistence mappers")
struct RideTripRecordMapperTests {
    @Test("Missing or unknown persisted attitude source is treated as legacy phone data")
    func mapsLegacyAttitudeSource() throws {
        let mapper = RideTripRecordMapper()
        let trip = RideSessionDataFixtures.makeTrip(
            identity: .vin(RideSessionDataFixtures.firstVIN),
            sessionID: UUID()
        )
        let record = mapper.makeRecord(from: trip)

        record.attitudeSourceRawValue = nil
        #expect(mapper.mapToDomain(record)?.attitudeSource == .legacyPhone)

        record.attitudeSourceRawValue = "unknown-future-source"
        #expect(mapper.mapToDomain(record)?.attitudeSource == .legacyPhone)
    }

    @Test("Persists exact VIN and temporary identity raw values")
    func persistsExactIdentityRawValues() {
        let tripMapper = RideTripRecordMapper()
        let bucketMapper = RideEnergyBucketRecordMapper()
        let temporaryID = UUID()
        let sessionID = UUID()
        let bucket = RideSessionDataFixtures.makeBucket()
        let vinTrip = RideSessionDataFixtures.makeTrip(
            identity: .vin(RideSessionDataFixtures.firstVIN),
            sessionID: sessionID,
            buckets: [bucket]
        )
        let temporaryTrip = RideSessionDataFixtures.makeTrip(
            identity: .temporary(temporaryID),
            sessionID: sessionID,
            buckets: [bucket]
        )

        let vinRecord = tripMapper.makeRecord(from: vinTrip)
        let temporaryRecord = tripMapper.makeRecord(from: temporaryTrip)
        let vinBucket = bucketMapper.makeRecord(from: bucket, trip: vinTrip)
        let temporaryBucket = bucketMapper.makeRecord(from: bucket, trip: temporaryTrip)

        #expect(vinRecord.vehicleIdentityKind == "vin")
        #expect(vinRecord.vehicleIdentityValue == RideSessionDataFixtures.firstVIN)
        #expect(temporaryRecord.vehicleIdentityKind == "temporary")
        #expect(temporaryRecord.vehicleIdentityValue == temporaryID.uuidString)
        #expect(vinBucket.vehicleIdentityKind == "vin")
        #expect(vinBucket.vehicleIdentityValue == RideSessionDataFixtures.firstVIN)
        #expect(temporaryBucket.vehicleIdentityKind == "temporary")
        #expect(temporaryBucket.vehicleIdentityValue == temporaryID.uuidString)
    }
}
