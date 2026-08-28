import Foundation
import RideSessionDomain

enum RideHistoryFixtures {
    static let vin = "FENRTEST000000001"
    static let secondVIN = "FENRTEST000000002"

    static func trip(
        id: UUID = UUID(),
        startedAt: Date,
        distance: Double = 10,
        duration: TimeInterval = 1_200,
        averageSpeed: Double = 30,
        maximumSpeed: Double = 70,
        efficiency: Double = 80,
        recoveredEnergy: Double = 80,
        coverage: Double = 1,
        buckets: [RideEnergyBucket] = []
    ) -> RideTrip {
        let expectedSeconds = max(duration, 1)
        return RideTrip(
            id: id,
            vehicleIdentity: .vin(vin),
            applicationSessionID: UUID(),
            startedAt: startedAt,
            updatedAt: startedAt.addingTimeInterval(duration),
            endedAt: startedAt.addingTimeInterval(duration),
            distanceKilometers: distance,
            elapsedSeconds: duration,
            averageSpeedKilometersPerHour: averageSpeed,
            maximumSpeedKilometersPerHour: maximumSpeed,
            consumedEnergyWattHours: distance * efficiency + recoveredEnergy,
            recoveredEnergyWattHours: recoveredEnergy,
            electricalObservedSeconds: expectedSeconds * coverage,
            electricalExpectedSeconds: expectedSeconds,
            maximumDischargePowerWatts: 18_000,
            maximumRegenerationPowerWatts: 7_500,
            maximumLeftLeanDegrees: 28,
            maximumRightLeanDegrees: 31,
            maximumUphillPitchDegrees: 9,
            maximumDownhillPitchDegrees: 7,
            energyBuckets: buckets
        )
    }

    static func buckets(startedAt: Date) -> [RideEnergyBucket] {
        var result: [RideEnergyBucket] = []
        for index in 0 ..< 4 {
            let bucketStart = Double(index) * 0.25
            let bucketEnd = Double(index + 1) * 0.25
            result.append(RideEnergyBucket(
                startedAt: startedAt.addingTimeInterval(Double(index * 30)),
                startDistanceKilometers: bucketStart,
                endDistanceKilometers: bucketEnd,
                stateOfChargePercent: 90 - index * 2,
                consumedEnergyWattHours: 22 + Double(index),
                recoveredEnergyWattHours: Double(index)
            ))
        }
        return result
    }
}
