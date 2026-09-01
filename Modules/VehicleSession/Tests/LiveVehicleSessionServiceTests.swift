import BikeDomain
import EnvironmentDomain
import Foundation
import SettingsDomain
import Testing
import TestSupport
@testable import VehicleSession

// The lifecycle scenarios intentionally share one complete dependency fixture.
// swiftlint:disable file_length

@Suite("Live vehicle session service")
struct LiveVehicleSessionServiceTests {
    @Test("Drains all source observations before a clean restart")
    func drainsObservationsBeforeRestart() async {
        let fixture = makeFixture(speedSource: .hybrid)
        await fixture.service.start()
        await fixture.service.start()
        _ = await fixture.service.observe()
        _ = await fixture.service.observe()
        #expect(await waitUntil {
            let sourceCounts = await fixture.repository.sourceSubscriptionCounts()
            let settingsCount = await fixture.settings.subscriptionCount()
            let profileCount = await fixture.profile.subscriptionCount()
            let deviceSpeedCount = await fixture.deviceSpeed.subscriptionCount()
            return sourceCounts == (1, 1)
                && settingsCount == 1
                && profileCount == 1
                && deviceSpeedCount == 1
        })

        await fixture.repository.sendTelemetry(.init(speed: .known(kmh: 35, kmhX10: 350)))
        await fixture.deviceSpeed.send(.init(
            kilometersPerHour: 42,
            accuracyMetersPerSecond: 1,
            observedAt: fixture.now
        ))
        #expect(await waitUntil { await fixture.latestSnapshot().resolvedSpeedKilometersPerHour == 42 })
        #expect(await fixture.latestSnapshot().speedSource == .hybrid)
        await fixture.service.stop()
        #expect(await waitUntil {
            let sourceCounts = await fixture.repository.activeSourceSubscriptionCounts()
            let imuCount = await fixture.imu.activeSubscriptionCount()
            let settingsCount = await fixture.settings.activeSubscriptionCount()
            let profileCount = await fixture.profile.activeSubscriptionCount()
            return sourceCounts == (0, 0)
                && imuCount == 0
                && settingsCount == 0
                && profileCount == 0
        })

        await fixture.service.start()
        #expect(await waitUntil {
            let sourceCounts = await fixture.repository.activeSourceSubscriptionCounts()
            let imuCount = await fixture.imu.activeSubscriptionCount()
            let settingsCount = await fixture.settings.activeSubscriptionCount()
            let profileCount = await fixture.profile.activeSubscriptionCount()
            return sourceCounts == (1, 1)
                && imuCount == 1
                && settingsCount == 1
                && profileCount == 1
        })
        await fixture.service.stop()
    }

    @Test("Slow observers retain only the newest vehicle snapshot")
    func boundsObserverBuffer() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        let stream = await fixture.service.observe()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        for speed in 1 ... 20 {
            await fixture.repository.sendTelemetry(.init(
                speed: .known(kmh: Double(speed), kmhX10: speed * 10)
            ))
        }
        #expect(await waitUntil { await fixture.latestSnapshot().telemetry.speed.kmh == 20 })

        #expect(await iterator.next()?.telemetry.speed.kmh == 20)
        await fixture.service.stop()
    }

    @Test("Three BMS consumers share one start and the last release performs one stop")
    func referenceCountsBatteryHealthConsumers() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        let consumers = [UUID(), UUID(), UUID()]
        for id in consumers {
            await fixture.service.setBatteryHealthMonitoringRequired(true, consumerID: id)
        }
        #expect(await waitUntil { await fixture.repository.monitoringCounts() == (1, 0) })

        await fixture.service.setBatteryHealthMonitoringRequired(false, consumerID: consumers[0])
        await fixture.service.setBatteryHealthMonitoringRequired(false, consumerID: consumers[1])
        #expect(await fixture.repository.monitoringCounts() == (1, 0))
        await fixture.service.setBatteryHealthMonitoringRequired(false, consumerID: consumers[2])
        #expect(await waitUntil { await fixture.repository.monitoringCounts() == (1, 1) })
    }

    @Test("A release during a pending BMS start stops it after startup finishes")
    func releaseDuringPendingStart() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        let consumer = UUID()
        await fixture.repository.delayNextStart()
        let request = Task {
            await fixture.service.setBatteryHealthMonitoringRequired(true, consumerID: consumer)
        }
        #expect(await waitUntil { await fixture.repository.hasPendingStart() })
        await fixture.service.setBatteryHealthMonitoringRequired(false, consumerID: consumer)
        await fixture.repository.resumeStart()
        await request.value

        #expect(await waitUntil { await fixture.repository.monitoringCounts() == (1, 1) })
        #expect(await fixture.latestSnapshot().batteryHealthMonitoringState == .inactive)
    }

    @Test("A failed BMS start can be retried")
    func retriesAfterFailure() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        let consumer = UUID()
        await fixture.repository.failNextStart()
        await fixture.service.setBatteryHealthMonitoringRequired(true, consumerID: consumer)
        #expect(await waitUntil {
            if case .failed = await fixture.latestSnapshot().batteryHealthMonitoringState { true } else { false }
        })

        await fixture.service.setBatteryHealthMonitoringRequired(false, consumerID: consumer)
        #expect(await fixture.latestSnapshot().batteryHealthMonitoringState == .inactive)
        await fixture.service.setBatteryHealthMonitoringRequired(true, consumerID: consumer)
        #expect(await waitUntil { await fixture.repository.monitoringCounts().0 == 2 })
        #expect(await waitUntil { await fixture.latestSnapshot().batteryHealthMonitoringState == .active })
    }

    @Test("Rearms BMS monitoring once after reconnect while consumers remain")
    func rearmsBatteryHealthMonitoringAfterReconnect() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        let consumers = [UUID(), UUID()]
        for consumer in consumers {
            await fixture.service.setBatteryHealthMonitoringRequired(true, consumerID: consumer)
        }
        #expect(await fixture.repository.monitoringCounts() == (0, 0))

        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        #expect(await waitUntil { await fixture.repository.monitoringCounts() == (1, 0) })

        await fixture.repository.sendConnection(.init(state: .reconnecting(
            vin: "FENRTEST000000001",
            attempt: 1,
            maximumAttempts: 5
        )))
        await fixture.repository.sendConnection(.init(state: .reconnecting(
            vin: "FENRTEST000000001",
            attempt: 2,
            maximumAttempts: 5
        )))
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))

        #expect(await waitUntil { await fixture.repository.monitoringCounts() == (2, 0) })
        #expect(await fixture.latestSnapshot().batteryHealthMonitoringState == .active)
        await fixture.service.stop()
    }

    @Test("Does not rearm BMS monitoring after consumers are released")
    func doesNotRearmBatteryHealthMonitoringWithoutConsumers() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        let consumer = UUID()
        await fixture.service.setBatteryHealthMonitoringRequired(true, consumerID: consumer)
        #expect(await waitUntil { await fixture.repository.monitoringCounts() == (1, 0) })
        await fixture.service.setBatteryHealthMonitoringRequired(false, consumerID: consumer)
        #expect(await waitUntil { await fixture.repository.monitoringCounts() == (1, 1) })

        await fixture.repository.sendConnection(.init(state: .reconnecting(
            vin: "FENRTEST000000001",
            attempt: 1,
            maximumAttempts: 5
        )))
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))

        #expect(await fixture.repository.monitoringCounts() == (1, 1))
        await fixture.service.stop()
    }

    @Test("Requires a fresh telemetry sample after reconnect")
    func requiresFreshTelemetryAfterReconnect() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        await fixture.repository.sendTelemetry(.init(
            batteryLevel: .known(percent: 72),
            lastUpdated: .init(timeIntervalSinceReferenceDate: 1)
        ))
        #expect(await waitUntil { await fixture.latestSnapshot().isCanonicalTelemetryAvailable })

        await fixture.repository.sendConnection(.init(state: .reconnecting(
            vin: "FENRTEST000000001",
            attempt: 1,
            maximumAttempts: 5
        )))
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))

        #expect(await waitUntil { !(await fixture.latestSnapshot().isCanonicalTelemetryAvailable) })
        await fixture.repository.sendTelemetry(.init(
            batteryLevel: .known(percent: 73),
            lastUpdated: .init(timeIntervalSinceReferenceDate: 2)
        ))
        #expect(await waitUntil { await fixture.latestSnapshot().isCanonicalTelemetryAvailable })
    }

    @Test("Balances a stale successful BMS start before rearming")
    func balancesStaleBatteryHealthStartAcrossReconnect() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        await fixture.repository.delayNextStart()
        let consumer = UUID()
        await fixture.service.setBatteryHealthMonitoringRequired(true, consumerID: consumer)
        #expect(await waitUntil { await fixture.repository.hasPendingStart() })

        await fixture.repository.sendConnection(.init(state: .reconnecting(
            vin: "FENRTEST000000001",
            attempt: 1,
            maximumAttempts: 5
        )))
        #expect(await waitUntil {
            if case .reconnecting = await fixture.latestSnapshot().connection.state {
                true
            } else {
                false
            }
        })
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        #expect(await waitUntil {
            if case .receivingTelemetry = await fixture.latestSnapshot().connection.state {
                true
            } else {
                false
            }
        })
        await fixture.repository.resumeStart()

        #expect(await waitUntil(timeout: .seconds(2)) {
            await fixture.repository.monitoringCounts() == (2, 1)
        })
        #expect(await fixture.latestSnapshot().batteryHealthMonitoringState == .active)
        await fixture.service.stop()
    }

}

extension LiveVehicleSessionServiceTests {
    @Test("Releasing the service balances active BMS monitoring")
    func deinitBalancesBatteryHealthMonitoring() async {
        var fixture: Fixture? = makeFixture()
        guard let repository = fixture?.repository else { return }
        await fixture?.service.start()
        #expect(await waitUntil { await repository.sourceSubscriptionCounts() == (1, 1) })
        await repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        await fixture?.service.setBatteryHealthMonitoringRequired(
            true,
            consumerID: UUID()
        )
        #expect(await waitUntil { await repository.monitoringCounts() == (1, 0) })

        fixture = nil

        #expect(await waitUntil { await repository.monitoringCounts() == (1, 1) })
        #expect(await waitUntil { await repository.activeHealthSubscriptionCount() == 0 })
    }

    @Test("Expires a GPS sample without waiting for another source event")
    func expiresDeviceSpeedSample() async {
        let sleepRecorder = VehicleSessionTestSleepRecorder()
        let now = Date(timeIntervalSince1970: 1_000)
        let fixture = makeFixture(
            speedSource: .gps,
            now: { now },
            maximumSampleAge: 0.75,
            sleep: { duration in await sleepRecorder.sleep(for: duration) }
        )
        await fixture.service.start()
        #expect(await waitUntil { await fixture.deviceSpeed.subscriptionCount() == 1 })
        await fixture.deviceSpeed.send(.init(
            kilometersPerHour: 42,
            accuracyMetersPerSecond: 1,
            observedAt: now.addingTimeInterval(-0.5)
        ))

        #expect(await waitUntil { await sleepRecorder.recordedDurations() == [.milliseconds(250)] })
        #expect(await waitUntil { !(await fixture.latestSnapshot().isGPSAvailable) })
        #expect(await fixture.latestSnapshot().resolvedSpeedKilometersPerHour == nil)
        await fixture.service.stop()
    }
}

extension LiveVehicleSessionServiceTests {
    @Test("Dynamics location consumer activates GPS with bike speed selected")
    func dynamicsLocationConsumer() async {
        let fixture = makeFixture(speedSource: .motorcycle)
        await fixture.service.start()
        #expect(await fixture.deviceSpeed.subscriptionCount() == 0)
        let consumerID = UUID()

        await fixture.service.setLocationMonitoringRequired(true, consumerID: consumerID)
        #expect(await waitUntil { await fixture.deviceSpeed.subscriptionCount() == 1 })
        let coordinate = GeographicCoordinate(latitudeDegrees: 40.4, longitudeDegrees: -3.7)
        await fixture.deviceSpeed.send(.init(
            kilometersPerHour: 20,
            accuracyMetersPerSecond: 1,
            altitudeMeters: 650,
            verticalAccuracyMeters: 2,
            coordinate: coordinate,
            observedAt: fixture.now
        ))
        #expect(await waitUntil { await fixture.latestSnapshot().motion.coordinate == coordinate })

        await fixture.service.setLocationMonitoringRequired(false, consumerID: consumerID)
        #expect(await fixture.latestSnapshot().motion.coordinate == nil)
        #expect(await fixture.latestSnapshot().motion.altitudeMeters == nil)
        await fixture.service.stop()
    }

    @Test("Refreshes missing base and optional traction once per mode visit")
    func refreshesPowerModeOnVisit() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        let baseOnly = BikePowerModeConfiguration(
            mapIndex: 0,
            horsepower: 60,
            regenerativeBrakingPercent: 40
        )

        await fixture.repository.sendTelemetry(.init(
            mode: .index(1),
            powerModeConfigurations: [0: baseOnly]
        ))
        #expect(await waitUntil {
            await fixture.repository.powerModeRefreshes() == (base: [], traction: [0])
        })
        await fixture.repository.sendTelemetry(.init(
            mode: .index(1),
            powerModeConfigurations: [0: baseOnly]
        ))
        #expect(await fixture.repository.powerModeRefreshes() == (base: [], traction: [0]))

        await fixture.repository.sendTelemetry(.init(mode: .index(2)))
        #expect(await waitUntil {
            await fixture.repository.powerModeRefreshes() == (base: [1], traction: [0, 1])
        })
        await fixture.repository.sendTelemetry(.init(
            mode: .index(1),
            powerModeConfigurations: [0: baseOnly]
        ))
        #expect(await waitUntil {
            await fixture.repository.powerModeRefreshes() == (base: [1], traction: [0, 1, 0])
        })
        await fixture.service.stop()
    }

    @Test("Refreshes the initial map when telemetry arrives before the session is ready")
    func refreshesInitialPowerModeAfterConnectionBecomesReady() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        let tractionOnly = BikePowerModeConfiguration(
            mapIndex: 0,
            powerTractionPercent: 20,
            brakingTractionPercent: 20
        )

        await fixture.repository.sendTelemetry(.init(
            mode: .index(1),
            powerModeConfigurations: [0: tractionOnly]
        ))
        #expect(await fixture.repository.powerModeRefreshes() == (base: [], traction: []))

        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        #expect(await waitUntil {
            await fixture.repository.powerModeRefreshes() == (base: [0], traction: [])
        })
        await fixture.service.stop()
    }

    @Test("A stale power mode refresh cannot finish the current generation")
    func stalePowerModeRefreshDoesNotDrainCurrentGeneration() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        await fixture.repository.suspendPowerModeRefresh(mapIndex: 0)
        await fixture.repository.sendTelemetry(.init(mode: .index(1)))
        #expect(await waitUntil { await fixture.repository.hasPendingPowerModeRefresh(mapIndex: 0) })

        await fixture.repository.sendConnection(.init(state: .disconnected(reason: "Link lost")))
        #expect(await waitUntil {
            await fixture.latestSnapshot().connection.state
                == .disconnected(reason: "Link lost")
        })
        await fixture.repository.suspendPowerModeRefresh(mapIndex: 1)
        await fixture.repository.sendTelemetry(.init(mode: .index(2)))
        #expect(await waitUntil { await fixture.latestSnapshot().telemetry.mode == .index(2) })
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        #expect(await waitUntil { await fixture.repository.hasPendingPowerModeRefresh(mapIndex: 1) })

        await fixture.repository.resumePowerModeRefresh(mapIndex: 0)
        #expect(await fixture.repository.hasPendingPowerModeRefresh(mapIndex: 1))
        #expect(await fixture.repository.powerModeRefreshes() == (base: [0, 1], traction: []))
        await fixture.repository.resumePowerModeRefresh(mapIndex: 1)
        #expect(await waitUntil { await fixture.repository.powerModeRefreshes() == (base: [0, 1], traction: [1]) })
        await fixture.service.stop()

        let restoredFixture = makeFixture()
        await restoredFixture.service.start()
        #expect(await waitUntil { await restoredFixture.repository.sourceSubscriptionCounts() == (1, 1) })
        let completeConfiguration = BikePowerModeConfiguration(
            mapIndex: 4,
            horsepower: 60,
            regenerativeBrakingPercent: 40,
            powerTractionPercent: 20,
            brakingTractionPercent: 20
        )
        await restoredFixture.repository.sendTelemetry(.init(
            mode: .index(5),
            powerModeConfigurations: [4: completeConfiguration]
        ))
        await restoredFixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        #expect(await restoredFixture.repository.powerModeRefreshes() == (base: [], traction: []))
        await restoredFixture.repository.sendTelemetry(.init(mode: .index(5)))
        #expect(await waitUntil {
            await restoredFixture.repository.powerModeRefreshes() == (base: [4], traction: [4])
        })
        await restoredFixture.service.stop()
    }

    @Test("Starts bike IMU monitoring and auto-calibrates a stable sample window")
    func autoCalibratesBikeIMU() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        #expect(await waitUntil { await fixture.imu.monitoringCounts().0 == 1 })
        await fixture.repository.sendTelemetry(.init(speed: .known(kmh: 0, kmhX10: 0)))
        for index in 0 ... 20 {
            await fixture.imu.send(.init(
                accelerationRaw: .init(x: 0, y: 0, z: 1_000),
                gyroscopeRaw: .init(x: 2, y: -1, z: 3),
                observedAt: fixture.now.addingTimeInterval(Double(index) / 10 - 2)
            ))
        }

        #expect(await waitUntil { await fixture.latestSnapshot().motion.availability == .available })
        #expect(await fixture.motionCalibration.savedValue()?.vin == "TESTVIN0000000001")
        await fixture.service.stop()
        #expect(await fixture.imu.monitoringCounts() == (1, 1))
    }

    @Test("Balances a stale successful IMU start before reconnecting")
    func balancesStaleIMUMonitoringStartAcrossReconnect() async {
        let sleepRecorder = VehicleSessionTestSleepRecorder()
        let fixture = makeFixture(
            maximumSampleAge: 0.75,
            sleep: { duration in await sleepRecorder.sleep(for: duration) }
        )
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })

        await fixture.imu.suspendNextStartIgnoringCancellation()
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        #expect(await waitUntil { await fixture.imu.hasPendingStart() })

        await fixture.repository.sendConnection(.init(state: .disconnected(reason: "Link lost")))
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        await fixture.imu.resumeStart()
        #expect(await waitUntil { await fixture.imu.monitoringCounts() == (2, 1) })

        await fixture.imu.send(.init(
            accelerationRaw: .init(x: 0, y: 0, z: 1_000),
            gyroscopeRaw: .init(x: 0, y: 0, z: 0),
            observedAt: fixture.now.addingTimeInterval(-0.5)
        ))
        #expect(await waitUntil { await sleepRecorder.recordedDurations() == [.milliseconds(250)] })
        await fixture.service.stop()
        #expect(await fixture.imu.monitoringCounts() == (2, 2))
    }

    @Test("Does not persist a zero before a bike IMU sample exists")
    func ignoresCalibrationWithoutSample() async {
        let fixture = makeFixture()
        await fixture.service.start()

        await fixture.service.zeroBikeAttitude()

        #expect(await fixture.motionCalibration.savedValue() == nil)
        await fixture.service.stop()
    }

    // The fixture intentionally spells out the complete production dependency graph.
    // swiftlint:disable:next function_body_length
    private func makeFixture(
        speedSource: SpeedSource = .motorcycle,
        now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_000) },
        maximumSampleAge: TimeInterval = 5,
        sleep: @escaping @Sendable (Duration) async throws -> Void = {
            try await Task.sleep(for: $0)
        }
    ) -> Fixture {
        let repository = VehicleSessionTestRepository()
        let settings = VehicleSessionTestSettingsRepository(speedSource: speedSource)
        let profile = VehicleSessionTestProfileRepository()
        let deviceSpeed = VehicleSessionTestDeviceSpeedRepository()
        let imu = VehicleSessionTestIMURepository()
        let motionCalibration = VehicleSessionTestMotionCalibrationRepository()
        let fixtureDate = now()
        let refreshPowerModeConfiguration = RefreshBikePowerModeConfigurationUseCase(
            repository: repository
        )
        let refreshTractionControlConfiguration = RefreshBikeTractionControlConfigurationUseCase(
            repository: repository
        )
        let observeBatteryHealth = ObserveBikeBatteryHealthUseCase(repository: repository)
        let startBatteryHealthMonitoring = StartBatteryHealthMonitoringUseCase(
            repository: repository
        )
        let stopBatteryHealthMonitoring = StopBatteryHealthMonitoringUseCase(
            repository: repository
        )
        let service = LiveVehicleSessionService(
            useCases: .init(
                observeTelemetry: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeSettings: .init(repository: settings),
                observeDeviceSpeed: .init(repository: deviceSpeed),
                observeIMU: .init(repository: imu),
                startIMUMonitoring: .init(repository: imu),
                stopIMUMonitoring: .init(repository: imu),
                loadMotionCalibration: .init(repository: motionCalibration),
                saveMotionCalibration: .init(repository: motionCalibration),
                observeBikeProfile: .init(repository: profile),
                observeBatteryHealth: observeBatteryHealth,
                startBatteryHealthMonitoring: startBatteryHealthMonitoring,
                stopBatteryHealthMonitoring: stopBatteryHealthMonitoring,
                readBikeStatusSnapshot: .init(repository: repository),
                refreshPowerModeConfiguration: refreshPowerModeConfiguration,
                refreshTractionControlConfiguration: refreshTractionControlConfiguration
            ),
            powerModeRefreshCoordinator: .init(
                refreshPowerModeConfiguration: refreshPowerModeConfiguration,
                refreshTractionControlConfiguration: refreshTractionControlConfiguration
            ),
            batteryHealthMonitoringCoordinator: .init(
                observeBatteryHealth: observeBatteryHealth,
                startBatteryHealthMonitoring: startBatteryHealthMonitoring,
                stopBatteryHealthMonitoring: stopBatteryHealthMonitoring
            ),
            speedResolver: .init(
                now: now,
                maximumAccuracyMetersPerSecond: 5,
                maximumSampleAge: maximumSampleAge
            ),
            motionEstimator: .init(
                profile: .init(
                    version: 1,
                    accelerationTransform: .init(
                        bikeX: .positiveX,
                        bikeY: .positiveY,
                        bikeZ: .positiveZ
                    ),
                    gyroscopeTransform: .init(
                        bikeX: .positiveX,
                        bikeY: .positiveY,
                        bikeZ: .positiveZ
                    ),
                    gyroscopeDegreesPerSecondPerRawUnit: .init(x: 0.01, y: 0.01, z: 0.01),
                    oneGRaw: 1_000
                ),
                now: now,
                maximumSampleAge: maximumSampleAge,
                minimumGPSCourseSpeedKilometersPerHour: 5,
                maximumGPSCourseAccuracyDegrees: 35
            ),
            sleep: sleep
        )
        return Fixture(
            service: service,
            repository: repository,
            settings: settings,
            profile: profile,
            deviceSpeed: deviceSpeed,
            imu: imu,
            motionCalibration: motionCalibration,
            now: fixtureDate
        )
    }

    private struct Fixture {
        let service: LiveVehicleSessionService
        let repository: VehicleSessionTestRepository
        let settings: VehicleSessionTestSettingsRepository
        let profile: VehicleSessionTestProfileRepository
        let deviceSpeed: VehicleSessionTestDeviceSpeedRepository
        let imu: VehicleSessionTestIMURepository
        let motionCalibration: VehicleSessionTestMotionCalibrationRepository
        let now: Date

        func latestSnapshot() async -> VehicleSessionSnapshot {
            let stream = await service.observe()
            for await snapshot in stream { return snapshot }
            fatalError("Vehicle session stream finished unexpectedly")
        }
    }
}
// swiftlint:enable file_length
