import BikeDomain
import Foundation
@testable import RideSession
import Testing
import TestSupport
import VehicleSession

@Suite("Live ride session service")
struct LiveRideSessionServiceTests {
    @Test("Records and persists a trip without creating dashboard UI")
    func recordsWithoutDashboard() async {
        let fixture = makeLiveRideSessionServiceFixture()
        await fixture.start()
        await fixture.bikeRepository.waitForSubscribers()
        await fixture.bikeRepository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        await fixture.bikeRepository.sendTelemetry(driveTelemetry())

        #expect(await waitUntil {
            await fixture.latestSnapshot().trip != nil
        })

        await fixture.service.persistCurrentTrip()
        #expect(await fixture.tripRepository.activeTrip() != nil)
        await fixture.stop()
    }

    @Test("Every observer immediately receives the current snapshot")
    func replaysCurrentSnapshot() async {
        let fixture = makeLiveRideSessionServiceFixture()
        await fixture.start()
        await fixture.bikeRepository.waitForSubscribers()
        await fixture.bikeRepository.sendConnection(.init(
            state: .receivingTelemetry(peripheralName: "TEST")
        ))
        await fixture.bikeRepository.sendTelemetry(driveTelemetry())
        #expect(await waitUntil { await fixture.latestSnapshot().trip != nil })

        let first = await fixture.latestSnapshot()
        let second = await fixture.latestSnapshot()

        #expect(first == second)
        #expect(first.trip != nil)
        await fixture.stop()
    }

    @Test("Resolves GPS+ speed once for all session consumers")
    func resolvesHybridSpeed() async {
        let fixture = makeLiveRideSessionServiceFixture(speedSource: .hybrid)
        await fixture.start()
        await fixture.deviceSpeedRepository.waitForSubscriber()
        await fixture.deviceSpeedRepository.send(.init(
            kilometersPerHour: 67,
            accuracyMetersPerSecond: 2,
            observedAt: fixture.date
        ))

        #expect(await waitUntil {
            await fixture.latestSnapshot().resolvedSpeedKilometersPerHour == 67
        })
        let snapshot = await fixture.latestSnapshot()
        #expect(snapshot.resolvedSpeedKilometersPerHour == 67)
        #expect(snapshot.speedSource == .hybrid)
        #expect(snapshot.isGPSAvailable)
        await fixture.stop()
    }

    @Test("Bounds the live power ring buffer to one hundred twenty samples")
    func boundsLivePowerBuffer() async {
        let fixture = makeLiveRideSessionServiceFixture()
        for index in 0 ..< 200 {
            await fixture.service.appendLivePowerSample(
                date: fixture.date.addingTimeInterval(Double(index) * 0.5),
                powerWatts: Double(index)
            )
        }

        let snapshot = await fixture.latestSnapshot()
        #expect(snapshot.livePowerSamples.count == 120)
        #expect(snapshot.livePowerSamples.first?.powerWatts == 80)
        #expect(snapshot.livePowerSamples.last?.powerWatts == 199)
    }

    @Test("Publishes a history revision only after a completed ride is deleted")
    func publishesDeletionRevision() async {
        let fixture = makeLiveRideSessionServiceFixture()
        await fixture.start()
        #expect(await waitUntil {
            await fixture.latestSnapshot().vehicleIdentity.confirmedVIN != nil
        })
        let vin = "TESTVIN0000000001"
        let rideID = UUID()
        let initialRevision = await fixture.latestSnapshot().historyRevision

        #expect(await fixture.service.deleteCompletedTrip(id: rideID, vin: vin))
        #expect(await fixture.tripRepository.deletedIDs() == [rideID])
        #expect(await fixture.latestSnapshot().historyRevision == initialRevision + 1)

        await fixture.tripRepository.setDeleteSucceeds(false)
        #expect(await fixture.service.deleteCompletedTrip(id: UUID(), vin: vin) == false)
        #expect(await fixture.latestSnapshot().historyRevision == initialRevision + 1)
        await fixture.stop()
    }
}

extension LiveRideSessionServiceTests {
    @Test("Stop completes the current trip exactly once")
    func stopCompletesCurrentTripExactlyOnce() async {
        let vehicleSession = SessionVehicleSessionService()
        let repository = SessionTripRepository()
        let fixture = makeLiveRideSessionServiceFixture(
            rideVehicleSession: vehicleSession,
            tripRepository: repository
        )
        await fixture.service.start()
        #expect(await waitUntil { await vehicleSession.subscriptionCounts().active == 1 })
        await vehicleSession.send(driveSnapshot())
        #expect(await waitUntil { await fixture.latestSnapshot().trip != nil })
        let tripID = await fixture.latestSnapshot().trip?.id

        await fixture.service.stop()
        await fixture.service.stop()

        let completedTrips = await repository.completedTrips()
        #expect(await repository.completionCount() == 1)
        #expect(completedTrips.count == 1)
        #expect(completedTrips.first?.id == tripID)
        #expect(completedTrips.first?.endedAt != nil)
        await vehicleSession.stop()
    }

    @Test("Stop persists the final trip and ignores telemetry after returning")
    func stopPersistsFinalTripAndIgnoresPostStopTelemetry() async {
        let vehicleSession = SessionVehicleSessionService()
        let repository = SessionTripRepository()
        let fixture = makeLiveRideSessionServiceFixture(
            rideVehicleSession: vehicleSession,
            tripRepository: repository
        )
        await fixture.service.start()
        #expect(await waitUntil { await vehicleSession.subscriptionCounts().active == 1 })
        await vehicleSession.send(driveSnapshot())
        #expect(await waitUntil { await fixture.latestSnapshot().trip != nil })

        await fixture.service.stop()
        let finalSaveCount = await repository.saveCount()
        let completedTrips = await repository.completedTrips()
        await vehicleSession.send(driveSnapshot(odometerKilometers: 101))

        #expect(await fixture.latestSnapshot().trip == nil)
        #expect(await repository.activeTrip() == nil)
        #expect(await repository.saveCount() == finalSaveCount)
        #expect(completedTrips.count == 1)
        #expect(completedTrips.first?.endedAt != nil)
        await vehicleSession.stop()
    }

    @Test("Stop waits for blocked preparation")
    func stopWaitsForBlockedPreparation() async {
        let vehicleSession = SessionVehicleSessionService()
        let repository = SessionTripRepository()
        await repository.blockNextPreparation()
        let fixture = makeLiveRideSessionServiceFixture(
            rideVehicleSession: vehicleSession,
            tripRepository: repository
        )
        await fixture.service.start()
        #expect(await waitUntil { await vehicleSession.subscriptionCounts().active == 1 })
        await vehicleSession.send(driveSnapshot())
        #expect(await waitUntil { await repository.hasBlockedPreparation() })
        let completion = SessionCompletionProbe()

        let stopTask = Task {
            await fixture.service.stop()
            await completion.complete()
        }
        #expect(await waitUntil { await fixture.service.stopTask != nil })
        #expect(await completion.count() == 0)
        await repository.resumePreparation()
        await stopTask.value

        #expect(await completion.count() == 1)
        #expect(await fixture.service.observationTasks.isEmpty)
        #expect(await fixture.service.preparationTask == nil)
        #expect(await fixture.service.tickerTask == nil)
        #expect(await repository.saveCount() == 0)
        await vehicleSession.stop()
    }

    @Test("Stop waits for blocked identity promotion")
    func stopWaitsForBlockedIdentityPromotion() async {
        let vehicleSession = SessionVehicleSessionService()
        let repository = SessionTripRepository()
        await repository.blockNextPromotion()
        let fixture = makeLiveRideSessionServiceFixture(
            rideVehicleSession: vehicleSession,
            tripRepository: repository
        )
        await fixture.service.start()
        #expect(await waitUntil { await vehicleSession.subscriptionCounts().active == 1 })
        await vehicleSession.send(driveSnapshot(hasReceivedProfile: false))
        #expect(await waitUntil { await repository.hasBlockedPromotion() })
        let completion = SessionCompletionProbe()

        let stopTask = Task {
            await fixture.service.stop()
            await completion.complete()
        }
        #expect(await waitUntil { await fixture.service.stopTask != nil })
        #expect(await completion.count() == 0)
        await repository.resumePromotion()
        await stopTask.value

        #expect(await completion.count() == 1)
        #expect(await fixture.service.observationTasks.isEmpty)
        #expect(await fixture.service.preparationTask == nil)
        #expect(await fixture.service.tickerTask == nil)
        #expect(await repository.saveCount() == 0)
        await vehicleSession.stop()
    }

}

extension LiveRideSessionServiceTests {
    @Test("Concurrent stops share a single teardown")
    func concurrentStopsShareSingleTeardown() async {
        let vehicleSession = SessionVehicleSessionService()
        let repository = SessionTripRepository()
        let fixture = makeLiveRideSessionServiceFixture(
            rideVehicleSession: vehicleSession,
            tripRepository: repository
        )
        await fixture.service.start()
        #expect(await waitUntil { await vehicleSession.subscriptionCounts().active == 1 })
        await vehicleSession.send(driveSnapshot())
        #expect(await waitUntil { await fixture.latestSnapshot().trip != nil })
        await repository.blockNextCompletion()
        let calls = SessionCallProbe()
        let completions = SessionCompletionProbe()

        let firstStop = Task {
            await calls.recordCall()
            await fixture.service.stop()
            await completions.complete()
        }
        let secondStop = Task {
            await calls.recordCall()
            await fixture.service.stop()
            await completions.complete()
        }
        #expect(await waitUntil { await calls.count() == 2 })
        #expect(await waitUntil { await repository.hasBlockedCompletion() })
        #expect(await completions.count() == 0)
        await repository.resumeCompletion()
        await firstStop.value
        await secondStop.value

        #expect(await completions.count() == 2)
        #expect(await repository.completionCount() == 1)
        #expect(await fixture.service.observationTasks.isEmpty)
        #expect(await fixture.service.preparationTask == nil)
        #expect(await fixture.service.tickerTask == nil)
        await vehicleSession.stop()
    }

    @Test("Start waits for stop before creating one replacement subscription")
    func startDuringStopDoesNotResubscribeAndRestartAfterStopDoes() async {
        let vehicleSession = SessionVehicleSessionService()
        let repository = SessionTripRepository()
        await repository.blockNextPreparation()
        let fixture = makeLiveRideSessionServiceFixture(
            rideVehicleSession: vehicleSession,
            tripRepository: repository
        )
        await fixture.service.start()
        #expect(await waitUntil { await vehicleSession.subscriptionCounts().active == 1 })
        await vehicleSession.send(driveSnapshot())
        #expect(await waitUntil { await repository.hasBlockedPreparation() })

        let stopTask = Task { await fixture.service.stop() }
        #expect(await waitUntil { await fixture.service.stopTask != nil })
        let startCompletion = SessionCompletionProbe()
        let startTask = Task {
            await fixture.service.start()
            await startCompletion.complete()
        }
        #expect(await waitUntil { await vehicleSession.subscriptionCounts().active == 0 })
        #expect(await vehicleSession.subscriptionCounts().total == 1)
        #expect(await startCompletion.count() == 0)

        await repository.resumePreparation()
        await stopTask.value
        await startTask.value

        #expect(await startCompletion.count() == 1)
        #expect(await waitUntil {
            let counts = await vehicleSession.subscriptionCounts()
            return counts.total == 2 && counts.active == 1
        })
        await fixture.service.stop()
        await vehicleSession.stop()
    }

    @Test("Stop cancels the ticker before it can persist another tick")
    func stopCancelsTickerBeforeItCanPersistAnotherTick() async {
        let vehicleSession = SessionVehicleSessionService()
        let repository = SessionTripRepository()
        let sleepController = SessionSleepController(ignoresCancellation: true)
        let fixture = makeLiveRideSessionServiceFixture(
            rideVehicleSession: vehicleSession,
            tripRepository: repository,
            sleepController: sleepController
        )
        await fixture.service.start()
        #expect(await waitUntil { await vehicleSession.subscriptionCounts().active == 1 })
        await vehicleSession.send(driveSnapshot())
        #expect(await waitUntil { await sleepController.hasPendingSleep() })
        let saveCountBeforeStop = await repository.saveCount()
        let completion = SessionCompletionProbe()

        let stopTask = Task {
            await fixture.service.stop()
            await completion.complete()
        }
        #expect(await waitUntil { await fixture.service.stopTask != nil })
        #expect(await completion.count() == 0)
        #expect(await sleepController.durations() == [.seconds(1)])
        await sleepController.resumeAll()
        await stopTask.value

        #expect(await completion.count() == 1)
        #expect(await repository.saveCount() == saveCountBeforeStop)
        #expect(await repository.completionCount() == 1)
        #expect(await fixture.service.tickerTask == nil)
        await vehicleSession.stop()
    }

    private func driveTelemetry() -> BikeTelemetry {
        BikeTelemetry(
            speed: .known(kmh: 42, kmhX10: 420),
            odometer: .known(kilometers: 100, centiKilometers: 10_000),
            statusFlags: .init(isOn: true, isInGear: true)
        )
    }

    private func driveSnapshot(
        odometerKilometers: Double = 100,
        hasReceivedProfile: Bool = true
    ) -> VehicleSessionSnapshot {
        let vin = "FENRTEST000000001"
        return VehicleSessionSnapshot(
            telemetry: BikeTelemetry(
                vin: vin,
                speed: .known(kmh: 42, kmhX10: 420),
                odometer: .known(
                    kilometers: odometerKilometers,
                    centiKilometers: UInt32(odometerKilometers * 100)
                ),
                statusFlags: .init(isOn: true, isInGear: true)
            ),
            connection: .init(state: .receivingTelemetry(peripheralName: "TEST")),
            profile: hasReceivedProfile ? .init(vin: vin) : nil,
            resolvedSpeedKilometersPerHour: 42,
            hasReceivedSettings: true,
            hasReceivedProfile: hasReceivedProfile
        )
    }

}
