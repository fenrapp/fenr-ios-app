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
                && fixture.viewModel.viewState.batteryIndicatorMode == .estimatedRange
        })
        #expect(fixture.viewModel.viewState.progressBar == .speed(progress: 42.0 / 180.0))
        #expect(await waitUntil { await fixture.vehicleSession.statusRefreshCount() == 1 })
        fixture.viewModel.stopObserving()
    }

    @Test("Reads status once per telemetry session without flooding the BLE queue")
    func refreshesStatusOncePerTelemetrySession() async {
        let fixture = makeFixture()
        fixture.viewModel.startObserving()

        for speed in 1 ... 5 {
            await fixture.vehicleSession.send(ridingSnapshot(speed: Double(speed)))
        }
        #expect(await waitUntil { await fixture.vehicleSession.statusRefreshCount() == 1 })

        await fixture.vehicleSession.send(.init(
            connection: .init(state: .disconnected(reason: "Synthetic disconnect")),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))
        await fixture.vehicleSession.send(ridingSnapshot(speed: 6))

        #expect(await waitUntil { await fixture.vehicleSession.statusRefreshCount() == 2 })
        fixture.viewModel.stopObserving()
    }

    @Test("Keeps temperature telemetry active across dashboard cards when enabled")
    func keepsTemperatureMonitoringActive() async {
        let fixture = makeFixture()
        fixture.viewModel.startObserving()

        await fixture.vehicleSession.send(ridingSnapshot(speed: 42, showsTemperatures: true))
        #expect(await waitUntil {
            await fixture.vehicleSession.recordedBatteryHealthMonitoringRequests() == [true]
        })

        await fixture.vehicleSession.send(ridingSnapshot(speed: 43, showsTemperatures: false))
        #expect(await waitUntil {
            await fixture.vehicleSession.recordedBatteryHealthMonitoringRequests() == [true, false]
        })
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

    @Test("Waits for stable telemetry before revealing the dashboard")
    func waitsForStableTelemetry() async throws {
        let fixture = makeFixture(initialConnectionStabilityPeriod: .milliseconds(40))
        fixture.viewModel.startObserving()

        await fixture.vehicleSession.send(ridingSnapshot(speed: 24))
        #expect(await waitUntil {
            fixture.viewModel.viewState.showsConnectionProgress
                && !fixture.viewModel.viewState.hasTelemetry
        })

        try await Task.sleep(for: .milliseconds(10))
        await fixture.vehicleSession.send(.init(
            connection: .init(state: .reconnecting(
                vin: "FENRTEST000000001",
                attempt: 1,
                maximumAttempts: 5
            )),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))
        try await Task.sleep(for: .milliseconds(50))
        #expect(!fixture.viewModel.viewState.hasTelemetry)
        #expect(fixture.viewModel.viewState.showsConnectionProgress)

        await fixture.vehicleSession.send(ridingSnapshot(speed: 42))
        #expect(await waitUntil { fixture.viewModel.viewState.hasTelemetry })
        #expect(fixture.viewModel.viewState.speedometer.valueText == "42")
        fixture.viewModel.stopObserving()
    }

    @Test("Presents connection phases as progress instead of disconnection")
    func mapsConnectionProgress() {
        let mapper = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US"))
        let states: [ConnectionState] = [
            .idle,
            .scanning(vin: "FENRTEST000000001"),
            .connecting(vin: "FENRTEST000000001", peripheralName: nil),
            .discovering(peripheralName: nil),
            .authenticating(peripheralName: nil),
            .authenticated(peripheralName: nil),
            .subscribed(peripheralName: nil),
            .reconnecting(vin: "FENRTEST000000001", attempt: 1, maximumAttempts: 5)
        ]

        for connectionState in states {
            let state = mapper.map(
                telemetry: BikeTelemetry(),
                connection: BikeConnection(state: connectionState),
                speedKilometersPerHour: nil,
                measurementSystem: .metric
            )
            #expect(state.showsConnectionProgress)
            #expect(!state.hasTelemetry)
            #expect(state.connectionDetail != "Connect your bike from Diagnostics.")
        }
    }

    private func makeFixture(
        initialConnectionStabilityPeriod: Duration = .zero,
        reconnectionGracePeriod: Duration = .seconds(30)
    ) -> Fixture {
        let vehicleSession = RideDashboardVehicleSession()
        return Fixture(
            viewModel: RideDashboardViewModel(
                mapper: RideDashboardMapperFactory.makeRideMapper(
                    locale: Locale(identifier: "en_GB")
                ),
                vehicleSession: vehicleSession,
                initialConnectionStabilityPeriod: initialConnectionStabilityPeriod,
                reconnectionGracePeriod: reconnectionGracePeriod
            ),
            vehicleSession: vehicleSession
        )
    }

    private func ridingSnapshot(
        speed: Double,
        showsTemperatures: Bool = false
    ) -> VehicleSessionSnapshot {
        .init(
            telemetry: .init(
                batteryLevel: .known(percent: 64),
                speed: .known(kmh: speed, kmhX10: Int((speed * 10).rounded())),
                statusFlags: .init(isOn: true, isInGear: true)
            ),
            connection: .init(state: .receivingTelemetry(peripheralName: "SYNTHETIC")),
            settings: .init(
                dashboardProgressBarMode: .speed,
                dashboardBatteryIndicatorMode: .estimatedRange,
                showsDashboardTemperatures: showsTemperatures,
                measurementSystem: .metric
            ),
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
