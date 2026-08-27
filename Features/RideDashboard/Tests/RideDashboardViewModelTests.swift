import BikeDomain
import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing
import TestSupport
import VehicleSession

@MainActor
@Suite("Ride dashboard view model")
struct RideDashboardViewModelTests {
    @Test("Maps the canonical vehicle snapshot and refreshes status")
    func mapsVehicleSessionSnapshot() async {
        let fixture = makeFixture()
        fixture.viewModel.startObserving()

        await fixture.vehicleSession.send(ridingSnapshot(speed: 42))

        #expect(await waitUntil {
            fixture.viewModel.viewState.speedometer.valueText == "42"
                && fixture.viewModel.viewState.battery.percentageText == "64%"
        })
        #expect(fixture.viewModel.viewState.progressBar == .speed(progress: 42.0 / 180.0))
        #expect(await waitUntil { await fixture.vehicleSession.statusRefreshCount() == 1 })
        fixture.viewModel.stopObserving()
    }

    @Test("Keeps live presentation during a brief reconnect and expires it")
    func preservesPresentationDuringReconnectionGrace() async {
        let fixture = makeFixture(reconnectionGracePeriod: .milliseconds(10))
        fixture.viewModel.startObserving()
        await fixture.vehicleSession.send(ridingSnapshot(speed: 51))
        #expect(await waitUntil { fixture.viewModel.viewState.hasTelemetry })

        await fixture.vehicleSession.send(.init(
            connection: .init(state: .disconnected(reason: "Synthetic disconnect")),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))

        #expect(fixture.viewModel.viewState.hasTelemetry)
        #expect(await waitUntil { !fixture.viewModel.viewState.hasTelemetry })
        fixture.viewModel.stopObserving()
    }

    private func makeFixture(
        reconnectionGracePeriod: Duration = .seconds(30)
    ) -> Fixture {
        let vehicleSession = RideDashboardVehicleSession()
        return Fixture(
            viewModel: RideDashboardViewModel(
                mapper: RideDashboardMapperFactory.makeRideMapper(
                    locale: Locale(identifier: "en_GB")
                ),
                vehicleSession: vehicleSession,
                reconnectionGracePeriod: reconnectionGracePeriod
            ),
            vehicleSession: vehicleSession
        )
    }

    private func ridingSnapshot(speed: Double) -> VehicleSessionSnapshot {
        .init(
            telemetry: .init(
                batteryLevel: .known(percent: 64),
                speed: .known(kmh: speed, kmhX10: Int((speed * 10).rounded())),
                statusFlags: .init(isOn: true, isInGear: true)
            ),
            connection: .init(state: .receivingTelemetry(peripheralName: "SYNTHETIC")),
            settings: .init(dashboardProgressBarMode: .speed, measurementSystem: .metric),
            resolvedSpeedKilometersPerHour: speed,
            hasReceivedSettings: true,
            hasReceivedProfile: true
        )
    }

    private struct Fixture {
        let viewModel: RideDashboardViewModel
        let vehicleSession: RideDashboardVehicleSession
    }
}
