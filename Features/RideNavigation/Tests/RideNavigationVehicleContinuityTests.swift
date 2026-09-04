import BikeDomain
@testable import RideNavigation
import Testing
import TestSupport
import VehicleSession

@MainActor
struct RideNavigationVehicleContinuityTests {
    @Test("Navigation preserves canonical metrics while reconnecting without owning the vehicle session")
    func navigationPreservesMetricsAcrossReconnect() async {
        let fixture = RideNavigationViewModelFixture()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(snapshot(
            batteryPercent: 25,
            mode: 4,
            connection: .receivingTelemetry(peripheralName: "Test Bike"),
            isCanonical: true
        ))
        #expect(await waitUntil {
            fixture.viewModel.viewState.batteryText == "25%"
                && fixture.viewModel.viewState.modeText == "MODE 4"
        })

        await fixture.vehicleSession.send(snapshot(
            batteryPercent: 2,
            mode: 1,
            connection: .reconnecting(
                vin: "FENRTEST000000001",
                attempt: 1,
                maximumAttempts: 3
            ),
            isCanonical: false
        ))
        #expect(await waitUntil {
            fixture.viewModel.viewState.batteryText == "25%"
                && fixture.viewModel.viewState.modeText == "MODE 4"
                && fixture.viewModel.viewState.connectionNoticeText == "Reconnecting to bike"
        })

        fixture.viewModel.setPresentationMode(.mini)
        fixture.viewModel.setPresentationMode(.fullScreen)
        await fixture.vehicleSession.send(snapshot(
            batteryPercent: 24,
            mode: 3,
            connection: .receivingTelemetry(peripheralName: "Test Bike"),
            isCanonical: true
        ))
        #expect(await waitUntil {
            fixture.viewModel.viewState.batteryText == "24%"
                && fixture.viewModel.viewState.modeText == "MODE 3"
                && fixture.viewModel.viewState.connectionNoticeText == nil
        })

        fixture.viewModel.stop()
        #expect(await fixture.vehicleSession.lifecycleCallCounts()
            == VehicleSessionLifecycleCallCounts(starts: 0, stops: 0))
    }

    @Test("Terminal disconnection invalidates cached navigation metrics")
    func terminalDisconnectionInvalidatesMetrics() async {
        let fixture = RideNavigationViewModelFixture()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(snapshot(
            batteryPercent: 70,
            mode: 2,
            connection: .receivingTelemetry(peripheralName: "Test Bike"),
            isCanonical: true
        ))
        #expect(await waitUntil { fixture.viewModel.viewState.batteryText == "70%" })

        await fixture.vehicleSession.send(snapshot(
            batteryPercent: 70,
            mode: 2,
            connection: .disconnected(reason: "Test disconnect"),
            isCanonical: false
        ))

        #expect(await waitUntil {
            fixture.viewModel.viewState.batteryText == "--%"
                && fixture.viewModel.viewState.modeText == "MODE --"
                && fixture.viewModel.viewState.connectionNoticeText == "Bike disconnected"
        })
        fixture.viewModel.stop()
    }

    private func snapshot(
        batteryPercent: Int,
        mode: Int,
        connection: ConnectionState,
        isCanonical: Bool
    ) -> VehicleSessionSnapshot {
        VehicleSessionSnapshot(
            telemetry: BikeTelemetry(
                batteryLevel: .known(percent: batteryPercent),
                mode: .index(mode),
                lastUpdated: .now
            ),
            connection: BikeConnection(state: connection),
            isCanonicalTelemetryAvailable: isCanonical
        )
    }
}
