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
                && fixture.viewModel.viewState.showsEstimatedRangeBatteryIndicator
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
        let gracePeriod = Duration.seconds(30)
        let timing = ControllableRideDashboardTiming()
        let fixture = makeFixture(
            timing: timing.makeTiming(),
            reconnectionGracePeriod: gracePeriod
        )
        fixture.viewModel.startObserving()
        await fixture.vehicleSession.send(ridingSnapshot(speed: 51))
        #expect(await waitUntil { await timing.pendingSleepCount(for: .zero) == 1 })
        await timing.resumeFirstSleep(for: .zero)
        #expect(await waitUntil { fixture.viewModel.viewState.hasTelemetry })

        await fixture.vehicleSession.send(.init(
            connection: .init(state: .disconnected(reason: "Synthetic disconnect")),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))

        #expect(fixture.viewModel.viewState.hasTelemetry)
        #expect(await waitUntil { await timing.pendingSleepCount(for: gracePeriod) == 1 })
        await timing.resumeFirstSleep(for: gracePeriod)
        #expect(await waitUntil { !fixture.viewModel.viewState.hasTelemetry })
        fixture.viewModel.stopObserving()
    }

    @Test("Waits for stable telemetry before revealing the dashboard")
    func waitsForStableTelemetry() async {
        let stabilityPeriod = Duration.seconds(1)
        let timing = ControllableRideDashboardTiming()
        let fixture = makeFixture(
            timing: timing.makeTiming(),
            initialConnectionStabilityPeriod: stabilityPeriod
        )
        fixture.viewModel.startObserving()

        await fixture.vehicleSession.send(ridingSnapshot(speed: 24))
        #expect(await waitUntil {
            fixture.viewModel.viewState.showsConnectionProgress
                && !fixture.viewModel.viewState.hasTelemetry
        })
        #expect(await waitUntil { await timing.pendingSleepCount(for: stabilityPeriod) == 1 })

        await fixture.vehicleSession.send(.init(
            connection: .init(state: .reconnecting(
                vin: "FENRTEST000000001",
                attempt: 1,
                maximumAttempts: 5
            )),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))
        #expect(await waitUntil { await timing.pendingSleepCount(for: stabilityPeriod) == 0 })
        #expect(!fixture.viewModel.viewState.hasTelemetry)
        #expect(fixture.viewModel.viewState.showsConnectionProgress)

        await fixture.vehicleSession.send(ridingSnapshot(speed: 42))
        #expect(await waitUntil {
            let requestCount = await timing.requestedSleepCount(for: stabilityPeriod)
            let pendingCount = await timing.pendingSleepCount(for: stabilityPeriod)
            return requestCount == 2 && pendingCount == 1
        })
        await timing.resumeFirstSleep(for: stabilityPeriod)
        #expect(await waitUntil { fixture.viewModel.viewState.hasTelemetry })
        #expect(fixture.viewModel.viewState.speedometer.valueText == "42")
        fixture.viewModel.stopObserving()
    }

    @Test("Canceled connection stability cannot publish stale telemetry")
    func cancelledConnectionStabilityCannotPublishStaleTelemetry() async {
        let stabilityPeriod = Duration.seconds(1)
        let timing = ControllableRideDashboardTiming()
        let fixture = makeFixture(
            timing: timing.makeTiming(),
            initialConnectionStabilityPeriod: stabilityPeriod
        )
        fixture.viewModel.startObserving()

        await fixture.vehicleSession.send(ridingSnapshot(speed: 24))
        #expect(await waitUntil { await timing.pendingSleepCount(for: stabilityPeriod) == 1 })

        await fixture.vehicleSession.send(.init(
            connection: .init(state: .reconnecting(
                vin: "FENRTEST000000001",
                attempt: 1,
                maximumAttempts: 5
            )),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))
        #expect(await waitUntil { await timing.pendingSleepCount(for: stabilityPeriod) == 0 })
        #expect(!fixture.viewModel.viewState.hasTelemetry)

        await fixture.vehicleSession.send(ridingSnapshot(speed: 42))
        #expect(await waitUntil { await timing.pendingSleepCount(for: stabilityPeriod) == 1 })
        await timing.resumeFirstSleep(for: stabilityPeriod)

        #expect(await waitUntil { fixture.viewModel.viewState.hasTelemetry })
        #expect(fixture.viewModel.viewState.speedometer.valueText == "42")
        fixture.viewModel.stopObserving()
    }

    @Test("Fresh telemetry cancels reconnection grace expiry")
    func freshTelemetryCancelsReconnectionGraceExpiry() async {
        let gracePeriod = Duration.seconds(30)
        let timing = ControllableRideDashboardTiming()
        let fixture = makeFixture(
            timing: timing.makeTiming(),
            reconnectionGracePeriod: gracePeriod
        )
        fixture.viewModel.startObserving()

        await fixture.vehicleSession.send(ridingSnapshot(speed: 51))
        #expect(await waitUntil { await timing.pendingSleepCount(for: .zero) == 1 })
        await timing.resumeFirstSleep(for: .zero)
        #expect(await waitUntil { fixture.viewModel.viewState.hasTelemetry })

        await fixture.vehicleSession.send(.init(
            connection: .init(state: .disconnected(reason: "Synthetic disconnect")),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))
        #expect(await waitUntil { await timing.pendingSleepCount(for: gracePeriod) == 1 })

        await fixture.vehicleSession.send(ridingSnapshot(speed: 52))
        #expect(await waitUntil { await timing.pendingSleepCount(for: gracePeriod) == 0 })
        #expect(fixture.viewModel.viewState.hasTelemetry)
        #expect(fixture.viewModel.viewState.speedometer.valueText == "52")
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
        timing: RideDashboardTiming = .live,
        initialConnectionStabilityPeriod: Duration = .zero,
        reconnectionGracePeriod: Duration = .seconds(30)
    ) -> Fixture {
        let vehicleSession = RideDashboardVehicleSession()
        return Fixture(
            viewModel: RideDashboardViewModel(
                mapper: RideDashboardMapperFactory.makeRideMapper(
                    locale: Locale(identifier: "en_GB")
                ),
                cardLayoutMapper: DashboardCardLayoutMapper(),
                vehicleSession: vehicleSession,
                timing: timing,
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
