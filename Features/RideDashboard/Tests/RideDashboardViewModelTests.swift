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

        await fixture.vehicleSession.send(ridingSnapshot(speed: 42, temperatureDisplayMode: .battery))
        #expect(await waitUntil {
            await fixture.vehicleSession.recordedBatteryHealthMonitoringRequests() == [true]
        })

        await fixture.vehicleSession.send(ridingSnapshot(speed: 43, temperatureDisplayMode: .inverter))
        await fixture.vehicleSession.send(ridingSnapshot(speed: 44, temperatureDisplayMode: .both))
        #expect(await fixture.vehicleSession.recordedBatteryHealthMonitoringRequests() == [true])

        await fixture.vehicleSession.send(ridingSnapshot(speed: 45, temperatureDisplayMode: .off))
        #expect(await waitUntil {
            await fixture.vehicleSession.recordedBatteryHealthMonitoringRequests() == [true, false]
        })
        fixture.viewModel.stopObserving()
    }

    @Test("Keeps live presentation and shows one notice after reconnect delay")
    func preservesPresentationDuringReconnect() async {
        let noticeDelay = Duration.seconds(5)
        let timing = ControllableRideDashboardTiming()
        let fixture = makeFixture(
            timing: timing.makeTiming(),
            reconnectionNoticeDelay: noticeDelay
        )
        fixture.viewModel.startObserving()
        await fixture.vehicleSession.send(ridingSnapshot(speed: 51))
        #expect(await waitUntil { await timing.pendingSleepCount(for: .zero) == 1 })
        await timing.resumeFirstSleep(for: .zero)
        #expect(await waitUntil { fixture.viewModel.viewState.hasTelemetry })

        await fixture.vehicleSession.send(.init(
            connection: .init(state: .reconnecting(
                vin: "FENRTEST000000001",
                attempt: 1,
                maximumAttempts: 5
            )),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))

        #expect(fixture.viewModel.viewState.hasTelemetry)
        #expect(fixture.viewModel.viewState.connectionNotice == nil)
        #expect(await waitUntil { await timing.pendingSleepCount(for: noticeDelay) == 1 })
        await timing.resumeFirstSleep(for: noticeDelay)
        #expect(await waitUntil { fixture.viewModel.viewState.connectionNotice?.text == "Reconnecting" })
        #expect(fixture.viewModel.viewState.hasTelemetry)
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

    @Test("Fresh telemetry cancels the reconnect notice")
    func freshTelemetryCancelsReconnectNotice() async {
        let noticeDelay = Duration.seconds(5)
        let timing = ControllableRideDashboardTiming()
        let fixture = makeFixture(
            timing: timing.makeTiming(),
            reconnectionNoticeDelay: noticeDelay
        )
        fixture.viewModel.startObserving()

        await fixture.vehicleSession.send(ridingSnapshot(speed: 51))
        #expect(await waitUntil { await timing.pendingSleepCount(for: .zero) == 1 })
        await timing.resumeFirstSleep(for: .zero)
        #expect(await waitUntil { fixture.viewModel.viewState.hasTelemetry })

        await fixture.vehicleSession.send(.init(
            connection: .init(state: .reconnecting(
                vin: "FENRTEST000000001",
                attempt: 1,
                maximumAttempts: 5
            )),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))
        #expect(await waitUntil { await timing.pendingSleepCount(for: noticeDelay) == 1 })

        await fixture.vehicleSession.send(ridingSnapshot(speed: 52))
        #expect(await waitUntil { await timing.pendingSleepCount(for: noticeDelay) == 0 })
        #expect(fixture.viewModel.viewState.hasTelemetry)
        #expect(fixture.viewModel.viewState.speedometer.valueText == "52")
        #expect(fixture.viewModel.viewState.connectionNotice == nil)
        fixture.viewModel.stopObserving()
    }

}

extension RideDashboardViewModelTests {
    @Test("Empty telemetry during a receiving reset keeps the last presentation")
    func emptyTelemetryRaceKeepsPresentation() async {
        let fixture = makeFixture()
        fixture.viewModel.startObserving()
        await fixture.vehicleSession.send(ridingSnapshot(speed: 38))
        #expect(await waitUntil { fixture.viewModel.viewState.hasTelemetry })

        await fixture.vehicleSession.send(.init(
            connection: .init(state: .receivingTelemetry(peripheralName: "SYNTHETIC")),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))

        #expect(await waitUntil {
            fixture.viewModel.viewState.hasTelemetry
                && fixture.viewModel.viewState.speedometer.valueText == "38"
                && fixture.viewModel.viewState.continuityPhase == .recovering
        })
        fixture.viewModel.stopObserving()
    }

    @Test("Cached telemetry cannot complete reconnect before a fresh sample")
    func cachedTelemetryCannotCompleteReconnect() async {
        let fixture = makeFixture()
        fixture.viewModel.startObserving()
        await fixture.vehicleSession.send(ridingSnapshot(speed: 38))
        #expect(await waitUntil { fixture.viewModel.viewState.hasTelemetry })

        await fixture.vehicleSession.send(ridingSnapshot(
            speed: 91,
            isCanonicalTelemetryAvailable: false
        ))

        #expect(await waitUntil {
            fixture.viewModel.viewState.continuityPhase == .recovering
        })
        #expect(fixture.viewModel.viewState.speedometer.valueText == "38")
        fixture.viewModel.stopObserving()
    }

    @Test("Explicit disconnect invalidates the cached presentation immediately")
    func explicitDisconnectIsTerminal() async {
        let fixture = makeFixture()
        fixture.viewModel.startObserving()
        await fixture.vehicleSession.send(ridingSnapshot(speed: 38))
        #expect(await waitUntil { fixture.viewModel.viewState.hasTelemetry })

        await fixture.vehicleSession.send(.init(
            connection: .init(state: .disconnected(reason: "Synthetic disconnect")),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))

        #expect(await waitUntil {
            !fixture.viewModel.viewState.hasTelemetry
                && fixture.viewModel.viewState.continuityPhase == .terminal
        })
        fixture.viewModel.stopObserving()
    }

    @Test("Resuming presentation replays live state without verifying again")
    func resumeDoesNotRepeatInitialVerification() async {
        let stabilityPeriod = Duration.seconds(1)
        let timing = ControllableRideDashboardTiming()
        let fixture = makeFixture(
            timing: timing.makeTiming(),
            initialConnectionStabilityPeriod: stabilityPeriod
        )
        fixture.viewModel.startObserving()
        await fixture.vehicleSession.send(ridingSnapshot(speed: 44))
        #expect(await waitUntil { await timing.pendingSleepCount(for: stabilityPeriod) == 1 })
        await timing.resumeFirstSleep(for: stabilityPeriod)
        #expect(await waitUntil { fixture.viewModel.viewState.hasTelemetry })

        fixture.viewModel.pausePresentation()
        fixture.viewModel.startObserving()

        #expect(await waitUntil { await fixture.vehicleSession.recordedObservationCount() == 2 })
        #expect(fixture.viewModel.viewState.hasTelemetry)
        #expect(fixture.viewModel.viewState.speedometer.valueText == "44")
        #expect(await timing.requestedSleepCount(for: stabilityPeriod) == 1)
        fixture.viewModel.stopObserving()
    }

    @Test("Preserves power details only while the active map index is unchanged")
    func powerModeContinuityIsScopedToActiveMap() async {
        let fixture = makeFixture()
        fixture.viewModel.startObserving()
        await fixture.vehicleSession.send(powerModeSnapshot(mode: 1, includesConfiguration: true))
        #expect(await waitUntil {
            fixture.viewModel.viewState.powerMode.horsepower == "60"
        })

        await fixture.vehicleSession.send(powerModeSnapshot(mode: 1, includesConfiguration: false))
        #expect(await waitUntil {
            fixture.viewModel.viewState.powerMode.horsepower == "60"
        })

        await fixture.vehicleSession.send(powerModeSnapshot(mode: 2, includesConfiguration: false))
        #expect(await waitUntil { !fixture.viewModel.viewState.powerMode.isVisible })
        fixture.viewModel.stopObserving()
    }

    @Test("Presents active connection phases as progress instead of disconnection")
    func mapsConnectionProgress() {
        let mapper = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US"))
        let states: [ConnectionState] = [
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

}
