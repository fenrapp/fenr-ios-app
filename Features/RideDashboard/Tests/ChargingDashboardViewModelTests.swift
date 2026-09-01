import BikeDomain
import ChargeControl
import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing
import TestSupport
import VehicleSession

@MainActor
@Suite("Charging dashboard view model")
struct ChargingDashboardViewModelTests {
    @Test("Requests battery health only while a charger is connected")
    func monitorsWhileChargerIsConnected() async {
        let fixture = makeFixture()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(.init())
        #expect(await fixture.vehicleSession.requirements().isEmpty)

        await fixture.vehicleSession.send(chargingSnapshot(health: chargingHealth()))
        #expect(await waitUntil { await fixture.vehicleSession.requirements() == [true] })
        #expect(await waitUntil { fixture.chargeControl.state.isEnabled })

        await fixture.vehicleSession.send(.init())
        #expect(await fixture.vehicleSession.requirements() == [true])
        #expect(await waitUntil { !fixture.chargeControl.state.isVisible })
        fixture.viewModel.stop()
        #expect(await waitUntil { await fixture.vehicleSession.requirements() == [true, false] })
    }

    @Test("Repeated charging snapshots do not duplicate monitoring requests")
    func coalescesMonitoringRequests() async {
        let fixture = makeFixture()
        fixture.viewModel.start()
        let snapshot = chargingSnapshot(health: chargingHealth())
        await fixture.vehicleSession.send(snapshot)
        await fixture.vehicleSession.send(snapshot)

        #expect(await waitUntil { await fixture.vehicleSession.requirements() == [true] })
        fixture.viewModel.stop()
        #expect(await waitUntil { await fixture.vehicleSession.requirements() == [true, false] })
    }

    @Test("Serializes monitoring acquisition and release")
    func serializesMonitoringRequirements() async {
        let vehicleSession = ChargingDashboardVehicleSession(
            monitoringEnableDelay: .milliseconds(20)
        )
        let fixture = makeFixture(vehicleSession: vehicleSession)
        fixture.viewModel.start()
        await vehicleSession.send(chargingSnapshot(health: chargingHealth()))
        #expect(await waitUntil {
            await vehicleSession.startedRequirements() == [true]
        })
        fixture.viewModel.stop()

        #expect(await waitUntil {
            await vehicleSession.requirements() == [true, false]
        })
    }

    @Test("Suspending preserves charging metrics while disabling controls")
    func suspensionPreservesPresentationAndDisablesControls() async {
        let fixture = makeFixture()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(chargingSnapshot(health: chargingHealth()))
        #expect(await waitUntil { fixture.chargeControl.state.isEnabled })
        let maximumPower = fixture.viewModel.viewState.maximumPower

        fixture.viewModel.suspend()

        #expect(!fixture.viewModel.viewState.control.isEnabled)
        #expect(fixture.viewModel.viewState.maximumPower == maximumPower)
        #expect(await waitUntil { await fixture.vehicleSession.requirements() == [true, false] })
    }

    private func makeFixture(
        vehicleSession: ChargingDashboardVehicleSession = .init()
    ) -> Fixture {
        let repository = ChargingDashboardRepository()
        let chargeControl = makeChargeControl(repository: repository)
        let locale = Locale(identifier: "en_US")
        let makeMapper: @Sendable (AppSettings, String?) -> ChargingDashboardMapper = { settings, vin in
            RideDashboardMapperFactory.makeChargingMapper(settings: settings, locale: locale, vin: vin)
        }
        return Fixture(
            viewModel: ChargingDashboardViewModel(
                vehicleSession: vehicleSession,
                chargeControl: chargeControl,
                mapper: makeMapper(AppSettings(), nil),
                makeMapper: makeMapper
            ),
            vehicleSession: vehicleSession,
            chargeControl: chargeControl
        )
    }

    private func makeChargeControl(repository: ChargingDashboardRepository) -> ChargeControlSession {
        ChargeControlSession(
            useCases: .init(
                prepare: .init(repository: repository),
                setPowerLimit: .init(repository: repository),
                setTarget: .init(repository: repository)
            ),
            logger: ChargeControlLogStore(),
            stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
            taskScheduler: ChargeControlTaskScheduler()
        )
    }

    private func chargingSnapshot(health: BikeBatteryHealth) -> VehicleSessionSnapshot {
        .init(
            telemetry: .init(
                statusFlags: .init(isChargerConnected: true),
                lastUpdated: .init(timeIntervalSinceReferenceDate: 1)
            ),
            connection: .init(state: .receivingTelemetry(peripheralName: "TEST")),
            batteryHealth: health,
            batteryHealthMonitoringState: .active
        )
    }

    private func chargingHealth() -> BikeBatteryHealth {
        .init(
            chargeState: .charging,
            chargingStatus: .init(
                requestedCurrentAmperes: 2.5,
                reportedCurrentAmperes: 2.5,
                maximumCurrentAmperes: 20,
                maximumPowerWatts: 1_000,
                targetCellVoltageVolts: 4.275,
                maximumStateOfChargePercent: 100,
                chargerType: .backpack
            )
        )
    }

    private struct Fixture {
        let viewModel: ChargingDashboardViewModel
        let vehicleSession: ChargingDashboardVehicleSession
        let chargeControl: ChargeControlSession
    }
}
