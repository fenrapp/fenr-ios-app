import BikeDomain
import Foundation
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("Live Activity availability and presentation")
struct BikeLiveActivityPreferencesTests {
    @Test("Disabled activities cannot start in the background", arguments: [true, false])
    func preventsStart(disableAll: Bool) async {
        let fixture = BikeLiveActivityControllerFixture()
        let preferences = LiveActivitySettings(isEnabled: !disableAll, showsCharging: disableAll)
        await fixture.settingsRepository.setSettings(.init(liveActivities: preferences))
        await prepare(fixture)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        #expect(await waitUntil { await fixture.currentSnapshot().telemetry.batteryLevel == .known(percent: 62) })
        #expect(fixture.activityClient.startCount == 0)
        #expect(await fixture.repository.monitoringStartCount() == 0)
        await fixture.controller.stop()
        await fixture.vehicleSession.stop()
    }

    @Test("Disabling an active charge dismisses immediately and releases only its monitoring")
    func dismissesActiveCharge() async {
        let fixture = BikeLiveActivityControllerFixture()
        await prepare(fixture)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        #expect(await waitUntil { fixture.activityClient.isActive })
        #expect(await waitUntil { await fixture.repository.monitoringStartCount() == 1 })
        await fixture.settingsRepository.setSettings(.init(liveActivities: .init(showsCharging: false)))
        #expect(await waitUntil { fixture.activityClient.dismissCount == 1 })
        #expect(await waitUntil { await fixture.repository.monitoringStopCount() == 1 })
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 62, mode: 2))
        #expect(await waitUntil { fixture.activityClient.startCount == 2 })
        #expect(fixture.activityClient.lastStartedState?.mode == .riding)
        await fixture.controller.stop()
        await fixture.vehicleSession.stop()
    }

    @Test("Presentation changes update an existing activity without waiting for telemetry throttle")
    func updatesPresentationImmediately() async {
        let fixture = BikeLiveActivityControllerFixture()
        await prepare(fixture)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 2))
        #expect(await waitUntil { fixture.activityClient.isActive })
        await fixture.settingsRepository.setSettings(.init(liveActivities: .init(ridingDetailLevel: .summary)))
        #expect(await waitUntil { fixture.activityClient.updatedStates.last?.showsDetails == false })
        #expect(fixture.activityClient.startCount == 1)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 72))
        #expect(await waitUntil { fixture.activityClient.updatedStates.last?.mode == .charging })
        #expect(fixture.activityClient.updatedStates.last?.showsDetails == true)
        await fixture.controller.stop()
        await fixture.vehicleSession.stop()
    }

    @Test("Disabling during reconnection cancels the notice and prevents a restart")
    func disableDuringRecovery() async {
        let fixture = BikeLiveActivityControllerFixture()
        await prepare(fixture)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 2))
        #expect(await waitUntil { fixture.activityClient.isActive })
        await fixture.repository.sendConnection(.init(state: .reconnecting(
            vin: "FENRTEST000000001", attempt: 1, maximumAttempts: 5
        )))
        await fixture.settingsRepository.setSettings(.init(liveActivities: .init(isEnabled: false)))
        #expect(await waitUntil { fixture.activityClient.dismissCount == 1 })
        await fixture.repository.sendConnection(.init(state: .receivingTelemetry(peripheralName: "Test bike")))
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 73, mode: 2))
        #expect(await waitUntil { await fixture.currentSnapshot().settings.liveActivities.isEnabled == false })
        #expect(!fixture.activityClient.isActive)
        await fixture.controller.stop()
        await fixture.vehicleSession.stop()
    }

    @Test("Disabling preserves battery monitoring requested by another consumer")
    func preservesOtherMonitoringConsumer() async {
        let fixture = BikeLiveActivityControllerFixture()
        await prepare(fixture)
        let consumerID = UUID()
        await fixture.vehicleSession.setBatteryHealthMonitoringRequired(true, consumerID: consumerID)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        #expect(await waitUntil { fixture.activityClient.isActive })
        await fixture.settingsRepository.setSettings(.init(liveActivities: .init(isEnabled: false)))
        #expect(await waitUntil { fixture.activityClient.dismissCount == 1 })
        await fixture.controller.stop()
        #expect(await fixture.repository.monitoringStopCount() == 0)
        await fixture.vehicleSession.setBatteryHealthMonitoringRequired(false, consumerID: consumerID)
        #expect(await waitUntil { await fixture.repository.monitoringStopCount() == 1 })
        await fixture.vehicleSession.stop()
    }

    @Test("Disabling waits for a pending update and then dismisses without restarting")
    func disablesDuringPendingUpdate() async {
        let fixture = BikeLiveActivityControllerFixture()
        await prepare(fixture)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 2))
        #expect(await waitUntil { fixture.activityClient.isActive })
        fixture.activityClient.blockNextUpdate()
        await fixture.settingsRepository.setSettings(.init(liveActivities: .init(ridingDetailLevel: .summary)))
        #expect(await waitUntil { fixture.activityClient.hasPendingUpdate })
        await fixture.settingsRepository.setSettings(.init(liveActivities: .init(isEnabled: false)))
        #expect(await waitUntil { await fixture.currentSnapshot().settings.liveActivities.isEnabled == false })
        fixture.activityClient.releasePendingUpdate()
        #expect(await waitUntil { fixture.activityClient.dismissCount == 1 })
        #expect(!fixture.activityClient.isActive)
        #expect(fixture.activityClient.startCount == 1)
        await fixture.controller.stop()
        await fixture.vehicleSession.stop()
    }

    @Test("Older activity payloads remain detailed")
    func olderContent() async throws {
        let fixture = BikeLiveActivityControllerFixture()
        await prepare(fixture)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        #expect(await waitUntil { fixture.activityClient.isActive })
        var state = try #require(fixture.activityClient.lastStartedState)
        state.showsDetails = nil
        let decoded = try JSONDecoder().decode(
            BikeLiveActivityContentState.self, from: JSONEncoder().encode(state)
        )
        #expect(decoded.usesDetailedPresentation)
        await fixture.controller.stop()
        await fixture.vehicleSession.stop()
    }

    private func prepare(_ fixture: BikeLiveActivityControllerFixture) async {
        await fixture.start()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.init(state: .receivingTelemetry(peripheralName: "Test bike")))
    }
}
