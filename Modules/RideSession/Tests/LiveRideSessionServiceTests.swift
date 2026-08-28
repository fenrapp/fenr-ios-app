import BikeDomain
import Foundation
@testable import RideSession
import Testing
import TestSupport

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

    private func driveTelemetry() -> BikeTelemetry {
        BikeTelemetry(
            speed: .known(kmh: 42, kmhX10: 420),
            odometer: .known(kilometers: 100, centiKilometers: 10_000),
            statusFlags: .init(isOn: true, isInGear: true)
        )
    }

}
