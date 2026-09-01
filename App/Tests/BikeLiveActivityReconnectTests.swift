import BikeDomain
import Foundation
import Testing
import TestSupport

@MainActor
@Suite("Bike Live Activity reconnect continuity")
struct BikeLiveActivityReconnectTests {
    @Test("Keeps existing content silent during a brief reconnect")
    func briefReconnectKeepsExistingContent() async {
        let fixture = BikeLiveActivityControllerFixture()
        await startRidingActivity(fixture)

        await fixture.repository.sendConnection(reconnectingConnection)
        await settleReconnectTest()

        #expect(fixture.activityClient.updateCount == 0)
        #expect(await waitUntil { await fixture.timing.pendingCount(for: .seconds(5)) == 1 })
    }

    @Test("Publishes reconnecting after five seconds and recovers with fresh content")
    func publishesReconnectNoticeAndRecovers() async {
        let fixture = BikeLiveActivityControllerFixture()
        await startRidingActivity(fixture)

        await fixture.repository.sendConnection(reconnectingConnection)
        #expect(await waitUntil { await fixture.timing.pendingCount(for: .seconds(5)) == 1 })
        await fixture.timing.resumeFirst(for: .seconds(5))
        #expect(await waitUntil {
            fixture.activityClient.updatedStates.last?.phase == .reconnecting
        })

        await fixture.repository.sendConnection(receivingConnection)
        await settleReconnectTest()
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 73, mode: 3))
        #expect(await waitUntil {
            fixture.activityClient.updatedStates.last?.phase == .riding
                && fixture.activityClient.updatedStates.last?.batteryPercent == 73
        })
        #expect(fixture.activityClient.startCount == 1)
    }

    @Test("Fresh recovery cancels a pending reconnect notice")
    func recoveryCancelsPendingReconnectNotice() async {
        let fixture = BikeLiveActivityControllerFixture()
        await startRidingActivity(fixture)
        await fixture.repository.sendConnection(reconnectingConnection)
        #expect(await waitUntil { await fixture.timing.pendingCount(for: .seconds(5)) == 1 })

        await fixture.repository.sendConnection(receivingConnection)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 73, mode: 3))

        #expect(await waitUntil { await fixture.timing.pendingCount(for: .seconds(5)) == 0 })
        #expect(!fixture.activityClient.updatedStates.contains { $0.phase == .reconnecting })
        #expect(await waitUntil {
            fixture.activityClient.updatedStates.last?.batteryPercent == 73
        })
    }

    @Test("A delayed reconnect update cannot overwrite recovered content")
    func delayedReconnectUpdateStaysSerialized() async {
        let fixture = BikeLiveActivityControllerFixture()
        await startRidingActivity(fixture)
        fixture.activityClient.blockNextUpdate()
        await fixture.repository.sendConnection(reconnectingConnection)
        #expect(await waitUntil { await fixture.timing.pendingCount(for: .seconds(5)) == 1 })
        await fixture.timing.resumeFirst(for: .seconds(5))
        #expect(await waitUntil { fixture.activityClient.hasPendingUpdate })

        await fixture.repository.sendConnection(receivingConnection)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 73, mode: 3))
        fixture.activityClient.releasePendingUpdate()

        #expect(await waitUntil {
            fixture.activityClient.updatedStates.last?.phase == .riding
                && fixture.activityClient.updatedStates.last?.batteryPercent == 73
        })
    }

    @Test("Receiving state without a fresh sample still shows reconnecting")
    func receivingWithoutFreshTelemetryRemainsRecovering() async {
        let fixture = BikeLiveActivityControllerFixture()
        await startRidingActivity(fixture)
        await fixture.repository.sendConnection(reconnectingConnection)
        #expect(await waitUntil { await fixture.timing.pendingCount(for: .seconds(5)) == 1 })
        await fixture.repository.sendConnection(receivingConnection)

        await fixture.timing.resumeFirst(for: .seconds(5))
        #expect(await waitUntil {
            fixture.activityClient.updatedStates.last?.phase == .reconnecting
        })

        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 73, mode: 3))
        #expect(await waitUntil {
            fixture.activityClient.updatedStates.last?.phase == .riding
                && fixture.activityClient.updatedStates.last?.batteryPercent == 73
        })
    }

    private func startRidingActivity(_ fixture: BikeLiveActivityControllerFixture) async {
        await fixture.start()
        await settleReconnectTest()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(receivingConnection)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 3))
        await settleReconnectTest()
    }

    private var receivingConnection: BikeConnection {
        .init(state: .receivingTelemetry(peripheralName: "Bike"))
    }

    private var reconnectingConnection: BikeConnection {
        .init(state: .reconnecting(
            vin: "FENRTEST000000001",
            attempt: 1,
            maximumAttempts: 5
        ))
    }

    private func settleReconnectTest() async {
        try? await Task.sleep(for: .milliseconds(20))
    }
}
