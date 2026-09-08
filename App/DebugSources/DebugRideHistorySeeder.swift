import BikeEmulator
import Foundation
import RideSessionDomain

struct DebugRideHistorySeeder: AppStartupPreparing {
    private let repository: any RideTripRepository
    private let now: @Sendable () -> Date

    init(
        repository: any RideTripRepository,
        now: @escaping @Sendable () -> Date
    ) {
        self.repository = repository
        self.now = now
    }

    func prepare() async {
        let vin = BikeEmulatorIdentity.vin
        guard let trips = try? await repository.loadCompletedTrips(vin: vin),
              trips.count < Constants.tripCount else { return }
        let referenceDate = now()
        for index in 0 ..< Constants.tripCount {
            let end = referenceDate.addingTimeInterval(-Double(Constants.tripCount - index) * 3_600)
            let duration = 1_200.0 + Double(index * 45)
            let distance = 9.0 + Double(index) * 0.8
            let consumed = distance * (78.0 - Double(index) * 2.4) + 55
            let recovered = 35.0 + Double((index * 17) % 70)
            let bucketDistance = distance / Double(Constants.bucketCount)
            let energyBuckets = (0 ..< Constants.bucketCount).map { bucketIndex in
                RideEnergyBucket(
                    startedAt: end.addingTimeInterval(
                        -duration + Double(bucketIndex) * duration / Double(Constants.bucketCount)
                    ),
                    startDistanceKilometers: Double(bucketIndex) * bucketDistance,
                    endDistanceKilometers: Double(bucketIndex + 1) * bucketDistance,
                    stateOfChargePercent: 92 - bucketIndex * 3,
                    consumedEnergyWattHours: consumed / Double(Constants.bucketCount),
                    recoveredEnergyWattHours: recovered / Double(Constants.bucketCount)
                )
            }
            let trip = RideTrip(
                vehicleIdentity: .vin(vin),
                applicationSessionID: UUID(),
                startedAt: end.addingTimeInterval(-duration),
                updatedAt: end,
                startingOdometerKilometers: 1_700 + Double(index) * 20,
                distanceKilometers: distance,
                elapsedSeconds: duration,
                averageSpeedKilometersPerHour: distance / duration * 3_600,
                maximumSpeedKilometersPerHour: 88 + Double(index * 3),
                consumedEnergyWattHours: consumed,
                recoveredEnergyWattHours: recovered,
                electricalObservedSeconds: duration * 0.97,
                electricalExpectedSeconds: duration,
                maximumDischargePowerWatts: 15_000 + Double(index * 500),
                maximumRegenerationPowerWatts: 6_000 + Double(index * 300),
                maximumLeftLeanDegrees: 18 + Double(index),
                maximumRightLeanDegrees: 21 + Double(index),
                maximumUphillPitchDegrees: 7 + Double(index) * 0.3,
                maximumDownhillPitchDegrees: 5 + Double(index) * 0.2,
                energyBuckets: energyBuckets
            )
            await repository.completeTrip(trip, at: end)
        }
    }
}

private extension DebugRideHistorySeeder {
    enum Constants {
        static let tripCount = 10
        static let bucketCount = 12
    }
}
