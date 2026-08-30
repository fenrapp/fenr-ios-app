import Foundation
import RideSessionDomain

enum RideSessionDataFixtures {
    static let firstVIN = "FENRTEST000000001"
    static let secondVIN = "FENRTEST000000002"
    static let referenceDate = Date(timeIntervalSince1970: 1_000)

    static func makeTrip(
        id: UUID = UUID(),
        identity: RideVehicleIdentity,
        sessionID: UUID,
        startedAt: Date = referenceDate,
        updatedAt: Date? = nil,
        endedAt: Date? = nil,
        distance: Double = 2,
        buckets: [RideEnergyBucket] = []
    ) -> RideTrip {
        RideTrip(
            id: id,
            vehicleIdentity: identity,
            applicationSessionID: sessionID,
            startedAt: startedAt,
            updatedAt: updatedAt ?? startedAt.addingTimeInterval(100),
            endedAt: endedAt,
            distanceKilometers: distance,
            elapsedSeconds: 100,
            consumedEnergyWattHours: distance * 70,
            recoveredEnergyWattHours: 10,
            electricalObservedSeconds: 95,
            electricalExpectedSeconds: 100,
            maximumLeftLeanDegrees: 31,
            maximumRightLeanDegrees: 26,
            maximumUphillPitchDegrees: 12,
            maximumDownhillPitchDegrees: 9,
            energyBuckets: buckets
        )
    }

    static func makeBucket(
        id: UUID = UUID(),
        startedAt: Date = referenceDate,
        updatedAt: Date? = nil
    ) -> RideEnergyBucket {
        RideEnergyBucket(
            id: id,
            startedAt: startedAt,
            updatedAt: updatedAt,
            startDistanceKilometers: 1,
            endDistanceKilometers: 1.25,
            stateOfChargePercent: 79,
            consumedEnergyWattHours: 22,
            recoveredEnergyWattHours: 3
        )
    }

    static func makeFullyPopulatedCompletedTrip(
        id: UUID = UUID(),
        sessionID: UUID = UUID(),
        bucket: RideEnergyBucket = makeBucket()
    ) -> RideTrip {
        let startedAt = referenceDate
        let updatedAt = startedAt.addingTimeInterval(1_800)
        return RideTrip(
            id: id,
            vehicleIdentity: .vin(firstVIN),
            applicationSessionID: sessionID,
            startedAt: startedAt,
            updatedAt: updatedAt,
            endedAt: updatedAt,
            startingOdometerKilometers: 1_234.5,
            distanceKilometers: 12.75,
            elapsedSeconds: 1_800,
            averageSpeedKilometersPerHour: 25.5,
            maximumSpeedKilometersPerHour: 91.25,
            accumulatedSpeedKilometersPerHourSeconds: 45_900,
            speedSampleDurationSeconds: 1_800,
            lastSpeedKilometersPerHour: 24.5,
            pausedAt: startedAt.addingTimeInterval(900),
            accumulatedPausedSeconds: 120,
            isAwaitingOdometerRebase: true,
            consumedEnergyWattHours: 980,
            recoveredEnergyWattHours: 125,
            electricalObservedSeconds: 1_740,
            electricalExpectedSeconds: 1_800,
            maximumDischargePowerWatts: 17_500,
            maximumRegenerationPowerWatts: 6_750,
            lastElectricalPowerWatts: -1_250,
            lastElectricalSampleAt: updatedAt.addingTimeInterval(-1),
            isAwaitingElectricalRebase: false,
            maximumLeftLeanDegrees: 32,
            maximumRightLeanDegrees: 29,
            maximumUphillPitchDegrees: 14,
            maximumDownhillPitchDegrees: 11,
            attitudeSource: .bikeIMUBetaV1,
            energyBuckets: [bucket]
        )
    }
}
