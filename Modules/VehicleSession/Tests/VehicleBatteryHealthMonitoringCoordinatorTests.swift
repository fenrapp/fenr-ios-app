import BikeDomain
import Foundation
import Testing
import TestSupport
@testable import VehicleSession

@Suite("Vehicle battery health monitoring coordinator")
struct VehicleBatteryHealthMonitoringCoordinatorTests {
    @Test("Preparation publishes starting before an immediate start can become active")
    func preparationPrecedesActiveMonitoring() async {
        let fixture = makeFixture()
        let consumerID = UUID()

        let prepared = await fixture.coordinator.prepareLeaseChange(
            required: true,
            consumerID: consumerID,
            isSessionReady: true
        )
        #expect(prepared.state == .starting)
        await fixture.coordinator.resumePendingWork()

        #expect(await waitUntil {
            await fixture.coordinator.snapshot().state == .active
        })
        #expect(await fixture.repository.monitoringCounts() == (1, 0))
    }

    @Test("Repeating an existing lease retries a failed start")
    func repeatedLeaseRetriesFailedStart() async {
        let fixture = makeFixture()
        let consumerID = UUID()
        await fixture.repository.failNextStart()

        _ = await fixture.coordinator.prepareLeaseChange(
            required: true,
            consumerID: consumerID,
            isSessionReady: true
        )
        await fixture.coordinator.resumePendingWork()
        #expect(await waitUntil {
            if case .failed = await fixture.coordinator.snapshot().state {
                true
            } else {
                false
            }
        })

        let retrying = await fixture.coordinator.prepareLeaseChange(
            required: true,
            consumerID: consumerID,
            isSessionReady: true
        )
        await fixture.coordinator.resumePendingWork()

        #expect(retrying.state == .starting)
        #expect(await waitUntil { await fixture.repository.monitoringCounts().0 == 2 })
        #expect(await waitUntil { await fixture.coordinator.snapshot().state == .active })
    }

    @Test("Health snapshots have monotonic revisions and observation ends with the lease")
    func publishesMonotonicHealthAndTearsDownObservation() async {
        let fixture = makeFixture()
        let consumerID = UUID()
        let starting = await fixture.coordinator.prepareLeaseChange(
            required: true,
            consumerID: consumerID,
            isSessionReady: true
        )
        await fixture.coordinator.resumePendingWork()
        #expect(await waitUntil { await fixture.repository.activeHealthSubscriptionCount() == 1 })
        let active = await fixture.coordinator.snapshot()
        let health = BikeBatteryHealth(positiveBMSFaultBits: 1)

        await fixture.repository.sendHealth(health)
        #expect(await waitUntil { await fixture.coordinator.snapshot().health == health })
        let measured = await fixture.coordinator.snapshot()
        let inactive = await fixture.coordinator.prepareLeaseChange(
            required: false,
            consumerID: consumerID,
            isSessionReady: true
        )
        await fixture.coordinator.resumePendingWork()

        #expect(starting.revision < active.revision)
        #expect(active.revision < measured.revision)
        #expect(measured.revision < inactive.revision)
        #expect(await waitUntil { await fixture.repository.activeHealthSubscriptionCount() == 0 })
        #expect(await waitUntil { await fixture.repository.monitoringCounts() == (1, 1) })
    }

    @Test("Reacquiring during a pending stop waits before restarting")
    func reacquiresAfterPendingStop() async {
        let fixture = makeFixture()
        let consumerID = UUID()
        _ = await fixture.coordinator.prepareLeaseChange(
            required: true,
            consumerID: consumerID,
            isSessionReady: true
        )
        await fixture.coordinator.resumePendingWork()
        #expect(await waitUntil { await fixture.coordinator.snapshot().state == .active })
        await fixture.repository.delayNextStop()

        _ = await fixture.coordinator.prepareLeaseChange(
            required: false,
            consumerID: consumerID,
            isSessionReady: true
        )
        await fixture.coordinator.resumePendingWork()
        #expect(await waitUntil { await fixture.repository.hasPendingStop() })
        let reacquired = await fixture.coordinator.prepareLeaseChange(
            required: true,
            consumerID: consumerID,
            isSessionReady: true
        )
        await fixture.coordinator.resumePendingWork()
        #expect(reacquired.state == .starting)
        #expect(await fixture.repository.monitoringCounts() == (1, 1))

        await fixture.repository.resumeStop()
        #expect(await waitUntil { await fixture.repository.monitoringCounts() == (2, 1) })
        #expect(await waitUntil { await fixture.coordinator.snapshot().state == .active })
    }

    @Test("Stop drains monitoring and the same coordinator can restart")
    func stopDrainsAndSupportsRestart() async {
        let fixture = makeFixture()
        let firstConsumer = UUID()
        _ = await fixture.coordinator.prepareLeaseChange(
            required: true,
            consumerID: firstConsumer,
            isSessionReady: true
        )
        await fixture.coordinator.resumePendingWork()
        #expect(await waitUntil { await fixture.coordinator.snapshot().state == .active })

        let stopped = await fixture.coordinator.stop()
        #expect(stopped.state == .inactive)
        #expect(await fixture.repository.monitoringCounts() == (1, 1))
        #expect(await waitUntil { await fixture.repository.activeHealthSubscriptionCount() == 0 })

        _ = await fixture.coordinator.prepareLeaseChange(
            required: true,
            consumerID: UUID(),
            isSessionReady: true
        )
        await fixture.coordinator.resumePendingWork()
        #expect(await waitUntil { await fixture.repository.monitoringCounts() == (2, 1) })
        #expect(await waitUntil { await fixture.coordinator.snapshot().state == .active })
    }
}

private extension VehicleBatteryHealthMonitoringCoordinatorTests {
    struct Fixture {
        let coordinator: VehicleBatteryHealthMonitoringCoordinator
        let repository: VehicleSessionTestRepository
    }

    func makeFixture() -> Fixture {
        let repository = VehicleSessionTestRepository()
        return Fixture(
            coordinator: .init(
                observeBatteryHealth: .init(repository: repository),
                startBatteryHealthMonitoring: .init(repository: repository),
                stopBatteryHealthMonitoring: .init(repository: repository)
            ),
            repository: repository
        )
    }
}
