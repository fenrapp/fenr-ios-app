import BikeDomain
import EnvironmentDomain
import Foundation
import SettingsDomain
import Testing
import TestSupport
@testable import VehicleSession

@Suite("Live vehicle session service")
struct LiveVehicleSessionServiceTests {
    @Test("Starts exactly one observation per source and replays the latest snapshot")
    func singleObservationAndReplay() async {
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

    @Test("Expires a GPS sample without waiting for another source event")
    func expiresDeviceSpeedSample() async {
        let fixture = makeFixture(
            speedSource: .gps,
            now: { Date() },
            maximumSampleAge: 0.05
        )
        await fixture.service.start()
        #expect(await waitUntil { await fixture.deviceSpeed.subscriptionCount() == 1 })
        await fixture.deviceSpeed.send(.init(
            kilometersPerHour: 42,
            accuracyMetersPerSecond: 1,
            observedAt: Date()
        ))

        #expect(await waitUntil { await fixture.latestSnapshot().isGPSAvailable })
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

    @Test("Calibrates fresh device motion for the active VIN")
    func calibratesDeviceMotion() async {
        let fixture = makeFixture()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.repository.sourceSubscriptionCounts() == (1, 1) })
        await fixture.repository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        #expect(await waitUntil { await fixture.deviceMotion.subscriptionCount() == 1 })
        await fixture.deviceMotion.send(.init(
            attitude: .init(
                xComponent: 0.1,
                yComponent: 0.2,
                zComponent: 0.3,
                scalarComponent: 0.9
            ),
            observedAt: fixture.now
        ))
        #expect(await waitUntil { await fixture.latestSnapshot().motion.availability == .uncalibrated })

        await fixture.service.calibrateDeviceMotion()

        #expect(await waitUntil { await fixture.latestSnapshot().motion.availability == .available })
        #expect(await fixture.motionCalibration.savedValue()?.vin == "TESTVIN0000000001")
        await fixture.service.stop()
    }

    @Test("Does not persist calibration before a device motion sample exists")
    func ignoresCalibrationWithoutSample() async {
        let fixture = makeFixture()
        await fixture.service.start()

        await fixture.service.calibrateDeviceMotion()

        #expect(await fixture.motionCalibration.savedValue() == nil)
        await fixture.service.stop()
    }

    private func makeFixture(
        speedSource: SpeedSource = .motorcycle,
        now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_000) },
        maximumSampleAge: TimeInterval = 5
    ) -> Fixture {
        let repository = VehicleSessionTestRepository()
        let settings = VehicleSessionTestSettingsRepository(speedSource: speedSource)
        let profile = VehicleSessionTestProfileRepository()
        let deviceSpeed = VehicleSessionTestDeviceSpeedRepository()
        let deviceMotion = VehicleSessionTestDeviceMotionRepository()
        let motionCalibration = VehicleSessionTestMotionCalibrationRepository()
        let fixtureDate = now()
        let service = LiveVehicleSessionService(
            useCases: .init(
                observeTelemetry: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeSettings: .init(repository: settings),
                observeDeviceSpeed: .init(repository: deviceSpeed),
                observeDeviceMotion: .init(repository: deviceMotion),
                loadMotionCalibration: .init(repository: motionCalibration),
                saveMotionCalibration: .init(repository: motionCalibration),
                observeBikeProfile: .init(repository: profile),
                observeBatteryHealth: .init(repository: repository),
                startBatteryHealthMonitoring: .init(repository: repository),
                stopBatteryHealthMonitoring: .init(repository: repository),
                readBikeStatusSnapshot: .init(repository: repository),
                refreshPowerModeConfiguration: .init(repository: repository),
                refreshTractionControlConfiguration: .init(repository: repository)
            ),
            speedResolver: .init(
                now: now,
                maximumAccuracyMetersPerSecond: 5,
                maximumSampleAge: maximumSampleAge
            ),
            motionEstimator: .init(
                now: now,
                maximumSampleAge: maximumSampleAge,
                minimumGPSCourseSpeedKilometersPerHour: 5,
                maximumGPSCourseAccuracyDegrees: 35,
                smoothingFactor: 1
            )
        )
        return Fixture(
            service: service,
            repository: repository,
            settings: settings,
            profile: profile,
            deviceSpeed: deviceSpeed,
            deviceMotion: deviceMotion,
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
        let deviceMotion: VehicleSessionTestDeviceMotionRepository
        let motionCalibration: VehicleSessionTestMotionCalibrationRepository
        let now: Date

        func latestSnapshot() async -> VehicleSessionSnapshot {
            let stream = await service.observe()
            for await snapshot in stream { return snapshot }
            fatalError("Vehicle session stream finished unexpectedly")
        }
    }
}
