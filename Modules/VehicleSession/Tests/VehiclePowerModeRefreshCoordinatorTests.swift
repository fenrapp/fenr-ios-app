import BikeDomain
import Testing
import TestSupport
@testable import VehicleSession

@Suite("Vehicle power mode refresh coordinator")
struct VehiclePowerModeRefreshCoordinatorTests {
    @Test("Ignores telemetry until the vehicle session is receiving")
    func ignoresTelemetryUntilReceiving() async {
        let fixture = makeFixture()

        await fixture.coordinator.update(
            telemetry: .init(mode: .index(1)),
            isReceivingTelemetry: false
        )

        #expect(await fixture.repository.powerModeRefreshes() == (base: [], traction: []))
    }

    @Test("Refreshes base configuration before traction control")
    func refreshesBaseBeforeTraction() async {
        let fixture = makeFixture()
        await fixture.repository.suspendPowerModeRefresh(mapIndex: 0)

        await fixture.coordinator.update(
            telemetry: .init(mode: .index(1)),
            isReceivingTelemetry: true
        )
        #expect(await waitUntil {
            await fixture.repository.hasPendingPowerModeRefresh(mapIndex: 0)
        })
        #expect(await fixture.repository.powerModeRefreshes() == (base: [0], traction: []))

        await fixture.repository.resumePowerModeRefresh(mapIndex: 0)
        #expect(await waitUntil {
            await fixture.repository.powerModeRefreshes() == (base: [0], traction: [0])
        })
    }

    @Test("Refreshes only missing configuration once per map visit")
    func refreshesOnlyMissingConfigurationOncePerVisit() async {
        let fixture = makeFixture()
        let baseOnly = BikePowerModeConfiguration(
            mapIndex: 0,
            horsepower: 60,
            regenerativeBrakingPercent: 40
        )
        let telemetry = BikeTelemetry(
            mode: .index(1),
            powerModeConfigurations: [0: baseOnly]
        )

        await fixture.coordinator.update(telemetry: telemetry, isReceivingTelemetry: true)
        #expect(await waitUntil {
            await fixture.repository.powerModeRefreshes() == (base: [], traction: [0])
        })
        await fixture.coordinator.update(telemetry: telemetry, isReceivingTelemetry: true)

        #expect(await fixture.repository.powerModeRefreshes() == (base: [], traction: [0]))
    }

    @Test("Revisiting a map permits a new missing configuration refresh")
    func revisitingMapPermitsRefresh() async {
        let fixture = makeFixture()

        await fixture.coordinator.update(
            telemetry: .init(mode: .index(1)),
            isReceivingTelemetry: true
        )
        #expect(await waitUntil {
            await fixture.repository.powerModeRefreshes() == (base: [0], traction: [0])
        })
        await fixture.coordinator.update(
            telemetry: .init(mode: .index(2)),
            isReceivingTelemetry: true
        )
        #expect(await waitUntil {
            await fixture.repository.powerModeRefreshes() == (base: [0, 1], traction: [0, 1])
        })
        await fixture.coordinator.update(
            telemetry: .init(mode: .index(1)),
            isReceivingTelemetry: true
        )

        #expect(await waitUntil {
            await fixture.repository.powerModeRefreshes() == (base: [0, 1, 0], traction: [0, 1, 0])
        })
    }

    @Test("Serializes a pending map refresh behind the active refresh")
    func serializesPendingRefresh() async {
        let fixture = makeFixture()
        await fixture.repository.suspendPowerModeRefresh(mapIndex: 0)

        await fixture.coordinator.update(
            telemetry: .init(mode: .index(1)),
            isReceivingTelemetry: true
        )
        #expect(await waitUntil {
            await fixture.repository.hasPendingPowerModeRefresh(mapIndex: 0)
        })
        await fixture.coordinator.update(
            telemetry: .init(mode: .index(2)),
            isReceivingTelemetry: true
        )
        #expect(await fixture.repository.powerModeRefreshes() == (base: [0], traction: []))

        await fixture.repository.resumePowerModeRefresh(mapIndex: 0)
        #expect(await waitUntil {
            await fixture.repository.powerModeRefreshes() == (base: [0, 1], traction: [0, 1])
        })
    }

    @Test("A stale completion cannot drain the current generation")
    func staleCompletionCannotDrainCurrentGeneration() async {
        let fixture = makeFixture()
        await fixture.repository.suspendPowerModeRefresh(mapIndex: 0)
        await fixture.coordinator.update(
            telemetry: .init(mode: .index(1)),
            isReceivingTelemetry: true
        )
        #expect(await waitUntil {
            await fixture.repository.hasPendingPowerModeRefresh(mapIndex: 0)
        })

        await fixture.coordinator.reset()
        await fixture.repository.suspendPowerModeRefresh(mapIndex: 1)
        await fixture.coordinator.update(
            telemetry: .init(mode: .index(2)),
            isReceivingTelemetry: true
        )
        #expect(await waitUntil {
            await fixture.repository.hasPendingPowerModeRefresh(mapIndex: 1)
        })

        await fixture.repository.resumePowerModeRefresh(mapIndex: 0)
        #expect(await fixture.repository.hasPendingPowerModeRefresh(mapIndex: 1))
        #expect(await fixture.repository.powerModeRefreshes() == (base: [0, 1], traction: []))
        await fixture.repository.resumePowerModeRefresh(mapIndex: 1)
        #expect(await waitUntil {
            await fixture.repository.powerModeRefreshes() == (base: [0, 1], traction: [1])
        })
    }
}

private extension VehiclePowerModeRefreshCoordinatorTests {
    struct Fixture {
        let coordinator: VehiclePowerModeRefreshCoordinator
        let repository: VehicleSessionTestRepository
    }

    func makeFixture() -> Fixture {
        let repository = VehicleSessionTestRepository()
        return Fixture(
            coordinator: .init(
                refreshPowerModeConfiguration: .init(repository: repository),
                refreshTractionControlConfiguration: .init(repository: repository)
            ),
            repository: repository
        )
    }
}
