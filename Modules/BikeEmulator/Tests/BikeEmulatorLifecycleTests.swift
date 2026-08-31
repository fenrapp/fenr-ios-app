import BikeDomain
@testable import BikeEmulator
import Foundation
import Testing
import TestSupport

@Suite("Bike emulator lifecycle")
struct BikeEmulatorLifecycleTests {
    @Test("Repeated starts share one periodic task")
    func repeatedStartsShareOnePeriodicTask() async {
        let fixture = await makeBikeEmulatorTestFixture()

        async let firstStart: Void = fixture.repository.start()
        async let secondStart: Void = fixture.repository.start()
        _ = await (firstStart, secondStart)

        #expect(await fixture.repository.lifecycleState == .started)
        #expect(await waitUntil {
            await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
        })
        await fixture.repository.stop()
    }

    @Test("Stop during startup prevents a stale periodic task")
    func stopDuringStartInvalidatesStartup() async {
        let fixture = await makeBikeEmulatorTestFixture()
        await fixture.runtime.suspendNow()
        let startTask = Task { await fixture.repository.start() }
        #expect(await waitUntil { await fixture.runtime.nowWaiterCount() == 1 })

        let stopTask = Task { await fixture.repository.stop() }
        #expect(await waitUntil { await fixture.repository.lifecycleState == .stopping })
        await fixture.runtime.resumeNow()
        await startTask.value
        await stopTask.value

        #expect(await fixture.repository.lifecycleState == .stopped)
        #expect(await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 0)
    }

    @Test("Stop waits for telemetry and IMU tasks and blocks later ticks")
    func stopAwaitsPeriodicTasks() async {
        let fixture = await makeBikeEmulatorTestFixture(scenario: .riding)
        let telemetryRecorder = BikeEmulatorStreamRecorder<BikeTelemetry>()
        let imuRecorder = BikeEmulatorStreamRecorder<BikeIMUSample>()
        await fixture.repository.start()
        let telemetryTask = Task {
            await telemetryRecorder.record(await fixture.repository.observeTelemetry())
        }
        let imuTask = Task {
            await imuRecorder.record(await fixture.repository.observeIMU())
        }
        await fixture.repository.startIMUMonitoring()
        #expect(await waitUntil {
            let telemetryCount = await fixture.runtime.waiterCount(
                for: fixture.runtime.telemetryInterval
            )
            let imuCount = await fixture.runtime.waiterCount(for: fixture.runtime.imuInterval)
            return telemetryCount == 1 && imuCount == 1
        })
        await fixture.runtime.setResumesCanceledSleeps(false)

        let stopTask = Task { await fixture.repository.stop() }
        #expect(await waitUntil { await fixture.repository.lifecycleState == .stopping })
        await fixture.runtime.resumeAll(date: Date(timeIntervalSince1970: 1_700_000_100))
        await fixture.runtime.setResumesCanceledSleeps(true)
        await stopTask.value
        #expect(await waitUntil { await telemetryRecorder.count == 2 })
        let telemetryCount = await telemetryRecorder.count
        let imuCount = await imuRecorder.count
        let resumedTelemetry = await fixture.runtime.resumeNext(for: fixture.runtime.telemetryInterval)
        let resumedIMU = await fixture.runtime.resumeNext(for: fixture.runtime.imuInterval)

        #expect(await fixture.repository.lifecycleState == .stopped)
        #expect(!resumedTelemetry)
        #expect(!resumedIMU)
        #expect(await telemetryRecorder.count == telemetryCount)
        #expect(await imuRecorder.count == imuCount)
        #expect(await telemetryRecorder.latest == BikeTelemetry())
        telemetryTask.cancel()
        imuTask.cancel()
    }

    @Test("Start during stop waits and opens a fresh generation")
    func startDuringStopWaitsForShutdown() async {
        let fixture = await makeBikeEmulatorTestFixture()
        await fixture.repository.start()
        #expect(await waitUntil {
            await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
        })
        await fixture.runtime.setResumesCanceledSleeps(false)

        let stopTask = Task { await fixture.repository.stop() }
        #expect(await waitUntil { await fixture.repository.lifecycleState == .stopping })
        let restartTask = Task { await fixture.repository.start() }
        #expect(await fixture.repository.lifecycleState == .stopping)

        await fixture.runtime.resumeAll()
        await fixture.runtime.setResumesCanceledSleeps(true)
        await stopTask.value
        await restartTask.value

        #expect(await fixture.repository.lifecycleState == .started)
        #expect(await waitUntil {
            await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
        })
        await fixture.repository.stop()
    }

    @Test("Restart clears monitoring leases and preparations")
    func restartClearsSessionState() async throws {
        let fixture = await makeBikeEmulatorTestFixture(
            scenario: .charging,
            powerModePreset: .alpha
        )
        await fixture.repository.start()
        try await fixture.repository.startBatteryHealthMonitoring()
        await fixture.repository.startIMUMonitoring()
        _ = try await fixture.repository.prepareBikeLockControl()
        try await fixture.repository.preparePowerModeControl(mapIndex: 3)
        try await fixture.repository.prepareTractionControl(mapIndex: 3)
        let healthStream = await fixture.repository.observeBatteryHealth()
        var healthIterator = healthStream.makeAsyncIterator()
        let health = try #require(await healthIterator.next())
        _ = try await fixture.repository.prepareChargePowerControl(
            chargingStatus: try #require(health.chargingStatus)
        )

        await fixture.repository.stop()
        await fixture.repository.start()

        #expect(await fixture.repository.batteryHealthMonitoringLeaseCount == 0)
        #expect(await fixture.repository.imuMonitoringLeaseCount == 0)
        #expect(await fixture.repository.preparedPowerModeIndexes.isEmpty)
        #expect(await fixture.repository.preparedTractionControlIndexes.isEmpty)
        #expect(await fixture.repository.isChargePowerPrepared == false)
        #expect(await fixture.repository.isBikeLockPrepared == false)
        #expect(await fixture.runtime.waiterCount(for: fixture.runtime.imuInterval) == 0)
        await fixture.repository.stop()
    }
}
