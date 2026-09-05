import Foundation
import MaintenanceDomain
import RideSessionDomain

@MainActor
struct DemoSeedPreparer {
    let identity: DemoIdentity
    let defaults: UserDefaults
    let rides: any RideTripRepository
    let maintenance: any MaintenanceRepository

    func prepare() async throws {
        guard !defaults.bool(forKey: Constants.seededKey) else { return }
        for index in 0 ..< 3 {
            try Task.checkCancellation()
            let end = identity.createdAt.addingTimeInterval(-Double(index + 1) * 86_400)
            let distance = 12.0 + Double(index) * 4
            let trip = RideTrip(
                id: Constants.tripIDs[index],
                vehicleIdentity: .vin(identity.vin), applicationSessionID: identity.id,
                startedAt: end.addingTimeInterval(-1_800), updatedAt: end,
                startingOdometerKilometers: 1_800 - Double(index) * 30,
                distanceKilometers: distance, elapsedSeconds: 1_800,
                averageSpeedKilometersPerHour: distance * 2, maximumSpeedKilometersPerHour: 72,
                consumedEnergyWattHours: distance * 70, recoveredEnergyWattHours: 85,
                electricalObservedSeconds: 1_800, electricalExpectedSeconds: 1_800,
                maximumDischargePowerWatts: 15_000, maximumRegenerationPowerWatts: 4_000,
                maximumLeftLeanDegrees: 18, maximumRightLeanDegrees: 21,
                maximumUphillPitchDegrees: 7, maximumDownhillPitchDegrees: 5
            )
            guard await rides.completeTrip(trip, at: end) else { throw DemoPreparationError.seedingFailed }
        }
        for (index, kind) in [MaintenanceKind.chainLubrication, .generalInspection].enumerated() {
            let entry = MaintenanceEntry(
                id: Constants.maintenanceIDs[index], vin: identity.vin,
                selection: .init(kind: kind),
                performedAt: identity.createdAt.addingTimeInterval(-Double(index + 1) * 604_800),
                odometerKilometers: 1_800 - Double(index) * 100,
                createdAt: identity.createdAt, updatedAt: identity.createdAt
            )
            guard await maintenance.save(entry) else { throw DemoPreparationError.seedingFailed }
        }
        defaults.set(true, forKey: Constants.seededKey)
    }

    private enum Constants {
        static let seededKey = "demo.seeded.v1"
        static let tripIDs = (1 ... 3).map {
            UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8($0)))
        }
        static let maintenanceIDs = (4 ... 5).map {
            UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8($0)))
        }
    }
}
