import Foundation
import RideSessionDomain
import Testing

@Suite("Ride range estimator")
struct RideRangeEstimatorTests {
    @Test("Blends median history with recent driving and becomes stable")
    func blendsHistoricalAndRecentEfficiency() {
        let estimate = RideRangeEstimator().estimate(
            trip: activeTrip(distance: 5, netEnergy: 400),
            historicalTrips: [80, 100, 120].map(historicalTrip(efficiency:)),
            stateOfChargePercent: 50,
            batteryCapacityWattHours: 7_200
        )

        #expect(estimate.typicalEfficiencyWattHoursPerKilometer == 100)
        #expect(estimate.currentEfficiencyWattHoursPerKilometer == 80)
        #expect(estimate.blendedEfficiencyWattHoursPerKilometer == 85)
        #expect(estimate.estimatedRangeKilometers == 3_600.0 / 85)
        #expect(estimate.confidence == .stable)
    }

    @Test("Does not fabricate range before any valid efficiency exists")
    func learnsWithoutEfficiency() {
        let estimate = RideRangeEstimator().estimate(
            trip: nil,
            historicalTrips: [],
            stateOfChargePercent: 80,
            batteryCapacityWattHours: 7_200
        )

        #expect(estimate.estimatedRangeKilometers == nil)
        #expect(estimate.remainingEnergyWattHours == 5_760)
        #expect(estimate.confidence == .learning)
    }

    @Test("Ignores net-recovery windows when projecting range")
    func ignoresNegativeRecentEfficiency() {
        let estimate = RideRangeEstimator().estimate(
            trip: activeTrip(distance: 2, netEnergy: -50),
            historicalTrips: [historicalTrip(efficiency: 90)],
            stateOfChargePercent: 50,
            batteryCapacityWattHours: 7_200
        )

        #expect(estimate.currentEfficiencyWattHoursPerKilometer == nil)
        #expect(estimate.blendedEfficiencyWattHoursPerKilometer == 90)
        #expect(estimate.estimatedRangeKilometers == 40)
    }

    private func activeTrip(distance: Double, netEnergy: Double) -> RideTrip {
        RideTrip(
            vehicleIdentity: .vin(Constants.vin),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            distanceKilometers: distance,
            energyBuckets: [
                RideEnergyBucket(
                    startedAt: .distantPast,
                    updatedAt: .distantFuture,
                    startDistanceKilometers: .zero,
                    endDistanceKilometers: distance,
                    stateOfChargePercent: 50,
                    consumedEnergyWattHours: max(netEnergy, .zero),
                    recoveredEnergyWattHours: max(-netEnergy, .zero)
                )
            ]
        )
    }

    private func historicalTrip(efficiency: Double) -> RideTrip {
        RideTrip(
            vehicleIdentity: .vin(Constants.vin),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            endedAt: .distantPast,
            distanceKilometers: 10,
            consumedEnergyWattHours: efficiency * 10,
            electricalObservedSeconds: 100,
            electricalExpectedSeconds: 100
        )
    }

    private enum Constants {
        static let vin = "TESTVIN0000000001"
    }
}
