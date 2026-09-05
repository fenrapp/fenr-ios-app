import BikeDomain
@testable import BikeEmulator
import Foundation
import Testing
import TestSupport

@Suite("Bike emulator observation")
struct BikeEmulatorObservationTests {
    @Test("One controlled tick shares one timestamp across published payloads")
    func controlledTickUsesOneTimestamp() async throws {
        let fixture = await makeBikeEmulatorTestFixture(scenario: .riding, capturesDiagnostics: true)
        try await fixture.repository.startBatteryHealthMonitoring()
        await fixture.repository.start()
        var telemetryIterator = (await fixture.repository.observeTelemetry()).makeAsyncIterator()
        var healthIterator = (await fixture.repository.observeBatteryHealth()).makeAsyncIterator()
        var captureIterator = (await fixture.repository.observeBatteryDatasetCaptures()).makeAsyncIterator()
        _ = try #require(await telemetryIterator.next())
        _ = try #require(await healthIterator.next())
        for _ in BatteryDataset.allCases {
            _ = try #require(await captureIterator.next())
        }
        #expect(await waitUntil {
            await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
        })
        let tickDate = Date(timeIntervalSince1970: 1_700_000_321)

        let resumedTick = await fixture.runtime.resumeNext(
            for: fixture.runtime.telemetryInterval,
            date: tickDate
        )
        #expect(resumedTick)
        let telemetry = try #require(await telemetryIterator.next())
        let health = try #require(await healthIterator.next())
        var captures: [BatteryDatasetCapture] = []
        for _ in BatteryDataset.allCases {
            captures.append(try #require(await captureIterator.next()))
        }

        #expect(telemetry.lastUpdated == tickDate)
        #expect(health.lastUpdated == tickDate)
        #expect(captures.allSatisfy { $0.date == tickDate })
        #expect(Set(captures.map(\.dataset)) == Set(BatteryDataset.allCases))
        await fixture.repository.stop()
    }

    @Test("Capture buffering keeps one complete latest dataset batch")
    func captureBufferKeepsLatestBatch() async throws {
        let fixture = await makeBikeEmulatorTestFixture(scenario: .charging, capturesDiagnostics: true)
        try await fixture.repository.startBatteryHealthMonitoring()
        await fixture.repository.start()
        let stream = await fixture.repository.observeBatteryDatasetCaptures()

        for tick in 1 ... 3 {
            #expect(await waitUntil {
                await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
            })
            let resumedTick = await fixture.runtime.resumeNext(
                for: fixture.runtime.telemetryInterval,
                date: Date(timeIntervalSince1970: 1_700_000_000 + Double(tick))
            )
            #expect(resumedTick)
            #expect(await waitUntil {
                await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
            })
            #expect(await fixture.repository.tick == tick)
        }

        var iterator = stream.makeAsyncIterator()
        var captures: [BatteryDatasetCapture] = []
        for _ in BatteryDataset.allCases {
            captures.append(try #require(await iterator.next()))
        }

        #expect(
            captures.map(\.hex)
                == Array(repeating: "Debug charging frame 3", count: BatteryDataset.allCases.count)
        )
        #expect(Set(captures.map(\.dataset)) == Set(BatteryDataset.allCases))
        await fixture.repository.stop()
    }

    @Test("Disconnect persists across ticks until a reconnect")
    func disconnectPersistsAcrossTicks() async throws {
        let fixture = await makeBikeEmulatorTestFixture(scenario: .riding)
        await fixture.repository.start()
        #expect(await waitUntil {
            await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
        })

        try await fixture.repository.disconnect()
        let disconnectedTick = await fixture.runtime.resumeNext(for: fixture.runtime.telemetryInterval)
        #expect(disconnectedTick)
        #expect(await waitUntil {
            await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
        })

        #expect(await fixture.repository.isConnected == false)
        #expect(await fixture.repository.tick == 0)

        try await fixture.repository.retrySecurityHandshake()
        let connectedTick = await fixture.runtime.resumeNext(for: fixture.runtime.telemetryInterval)
        #expect(connectedTick)
        #expect(await waitUntil { await fixture.repository.tick == 1 })
        #expect(await fixture.repository.isConnected)
        await fixture.repository.stop()
    }

    @Test("Periodic ticks do not duplicate an unchanged connection")
    func periodicTicksDeduplicateConnection() async {
        let fixture = await makeBikeEmulatorTestFixture(scenario: .riding)
        await fixture.repository.start()
        let recorder = BikeEmulatorStreamRecorder<BikeConnection>()
        let task = Task {
            await recorder.record(await fixture.repository.observeConnection())
        }
        #expect(await waitUntil { await recorder.count == 1 })

        for _ in 0 ..< 3 {
            #expect(await waitUntil {
                await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
            })
            let resumedTick = await fixture.runtime.resumeNext(for: fixture.runtime.telemetryInterval)
            #expect(resumedTick)
        }
        #expect(await waitUntil { await fixture.repository.tick == 3 })

        #expect(await recorder.count == 1)
        task.cancel()
        await fixture.repository.stop()
    }

    @Test("Periodic telemetry does not repeat an unchanged connection")
    func periodicUpdatesSkipUnchangedConnection() async {
        let fixture = await makeBikeEmulatorTestFixture(scenario: .riding)
        let recorder = BikeEmulatorStreamRecorder<BikeConnection>()

        await fixture.repository.start()
        let task = Task {
            await recorder.record(await fixture.repository.observeConnection())
        }
        #expect(await waitUntil { await recorder.count == 1 })
        #expect(await waitUntil {
            await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
        })

        let resumedTick = await fixture.runtime.resumeNext(for: fixture.runtime.telemetryInterval)
        #expect(resumedTick)
        #expect(await waitUntil { await fixture.repository.tick == 1 })
        #expect(await recorder.count == 1)

        task.cancel()
        await fixture.repository.stop()
    }

    @Test("Clean riding scenario moves without activating indicators")
    func cleanRidingScenarioHasNoIndicators() async throws {
        let fixture = await makeBikeEmulatorTestFixture(scenario: .ridingClean)
        await fixture.repository.start()
        var iterator = (await fixture.repository.observeTelemetry()).makeAsyncIterator()
        _ = try #require(await iterator.next())
        #expect(await waitUntil {
            await fixture.runtime.waiterCount(for: fixture.runtime.telemetryInterval) == 1
        })

        let resumedTick = await fixture.runtime.resumeNext(for: fixture.runtime.telemetryInterval)
        #expect(resumedTick)
        let telemetry = try #require(await iterator.next())

        #expect(telemetry.speed.kmh ?? .zero > .zero)
        #expect(telemetry.statusFlags.indicatorState == .init())
        #expect(!telemetry.statusFlags.isBrakeActive)
        #expect(!telemetry.statusFlags.isFaultActive)
        await fixture.repository.stop()
    }
}
