import BikeDomain
import BikeEmulator
import ChargeControl
import Foundation
import TestSupport
import VehicleSession

@MainActor
struct AppChargingFixture {
    let repository: BikeEmulatorRepository
    let hub: TestEventHub<VehicleSessionSnapshot>
    let vehicle: CompanionVehicleSessionSpy
    let preferences: ChargingPreferencesController
    let session: ChargeControlSession
    let controller: AppChargingController

    static func make() async throws -> Self {
        let repository = BikeEmulatorRepositoryFactory.make(scenario: .riding)
        await repository.start()
        try await repository.connect(vin: BikeEmulatorIdentity.vin)
        let hub = TestEventHub<VehicleSessionSnapshot>(bufferingPolicy: .unbounded)
        let vehicle = CompanionVehicleSessionSpy(hub: hub)
        let preferences = ChargingPreferencesController(
            useCases: .init(repository: repository), store: ChargingPreferencesMemoryStore(),
            emitter: ChargingPreferencesEmitter()
        )
        let session = ChargeControlSession(
            useCases: .init(
                prepare: .init(repository: repository), setPowerLimit: .init(repository: repository),
                setTarget: .init(repository: repository)
            ),
            logger: .init(isRecording: { false }), stateUpdater: .init(normalizer: .init()),
            taskScheduler: .init(), stateEmitter: .init(), preferencesController: preferences
        )
        return .init(
            repository: repository, hub: hub, vehicle: vehicle, preferences: preferences, session: session,
            controller: .init(vehicleSession: vehicle, session: session, preferences: preferences)
        )
    }

    func publish(connected: Bool, charger: Bool = false, matchesBike: Bool = true) async {
        var telemetry = BikeTelemetry(vin: matchesBike ? BikeEmulatorIdentity.vin : "FENRTEST000000002")
        telemetry.lastUpdated = Date()
        telemetry.statusFlags = .init(isChargerConnected: charger)
        await hub.send(.init(
            telemetry: telemetry,
            connection: .init(state: connected ? .receivingTelemetry(peripheralName: nil) : .disconnected(reason: nil)),
            profile: .init(vin: BikeEmulatorIdentity.vin),
            isCanonicalTelemetryAvailable: connected
        ))
    }
}
