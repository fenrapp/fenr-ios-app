import BikeDomain
import Testing

@MainActor
@Suite("Bike Live Activity controller")
struct BikeLiveActivityControllerTests {
    @Test("Does not start with default telemetry")
    func doesNotStartWithDefaultTelemetry() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(BikeTelemetry())
        await settle()

        #expect(fixture.activityClient.startCount == 0)
        #expect(await fixture.repository.monitoringStartCount() == 0)
    }

    @Test("Does not start during onboarding")
    func doesNotStartDuringOnboarding() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()

        #expect(fixture.activityClient.startCount == 0)
    }

    @Test("Does not start in foreground")
    func doesNotStartInForeground() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 3))
        await settle()

        #expect(fixture.activityClient.startCount == 0)
    }

    @Test("Starts automatically in background while charging")
    func startsInBackgroundWhileCharging() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()

        #expect(fixture.activityClient.startCount == 1)
        #expect(fixture.activityClient.lastStartedVIN == "FENRTEST000000001")
        #expect(fixture.activityClient.lastStartedState?.mode == .charging)
        #expect(await fixture.repository.monitoringStartCount() == 1)
    }

    @Test("Starts automatically in background while riding")
    func startsInBackgroundWhileRiding() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 3))
        await settle()

        #expect(fixture.activityClient.startCount == 1)
        #expect(fixture.activityClient.lastStartedState?.mode == .riding)
        #expect(fixture.activityClient.lastStartedState?.modeIndex == 3)
        #expect(await fixture.repository.monitoringStartCount() == 0)
    }

    @Test("Starts on first background transition when charging was already observed")
    func startsOnFirstBackgroundTransitionAfterChargingWasObserved() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()
        fixture.controller.setCanShowLiveActivity(true)
        await settle()

        #expect(fixture.activityClient.startCount == 1)
        #expect(fixture.activityClient.lastStartedVIN == "FENRTEST000000001")
        #expect(await fixture.repository.monitoringStartCount() == 1)
    }

    @Test("Requests activity before waiting for battery health monitoring")
    func requestsActivityBeforeBatteryHealthMonitoringCompletes() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        await fixture.repository.delayNextMonitoringStart()
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()
        fixture.controller.setCanShowLiveActivity(true)
        await settle()

        #expect(fixture.activityClient.startCount == 1)
        #expect(await fixture.repository.monitoringStartCount() == 0)
    }

    @Test("Stops delayed monitoring if charge ends before monitoring starts")
    func stopsDelayedMonitoringWhenChargeEndsBeforeMonitoringStarts() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        await fixture.repository.delayNextMonitoringStart()
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()
        fixture.controller.setCanShowLiveActivity(true)
        await settle()
        await fixture.repository.sendTelemetry(idleTelemetry(percent: 62))
        await settle()
        await settle(milliseconds: 120)

        #expect(fixture.activityClient.endCount == 1)
        #expect(await fixture.repository.monitoringStartCount() == 1)
        #expect(await fixture.repository.monitoringStopCount() == 1)
    }

    @Test("Does not duplicate activities across repeated background transitions")
    func doesNotDuplicateActivities() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()
        fixture.controller.setCanShowLiveActivity(false)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 63))
        await settle()

        #expect(fixture.activityClient.startCount == 1)
    }

    @Test("Throttles non-critical updates to thirty seconds")
    func throttlesUpdates() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()
        fixture.clock.advance(by: 29)
        await fixture.repository.sendBatteryHealth(chargingHealth(target: 90, current: 4))
        await settle()
        #expect(fixture.activityClient.updateCount == 0)

        fixture.clock.advance(by: 1)
        await fixture.repository.sendBatteryHealth(chargingHealth(target: 90, current: 5))
        await settle()
        #expect(fixture.activityClient.updateCount == 1)
    }

    @Test("Allows immediate updates for critical phase changes")
    func updatesCriticalPhaseImmediately() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 62))
        await settle()
        await fixture.repository.sendConnection(BikeConnection(state: .disconnected(reason: "Out of range")))
        await settle()

        #expect(fixture.activityClient.updateCount == 1)
        #expect(fixture.activityClient.updatedStates.last?.phase == .connectionLost)
    }

    @Test("Updates immediately when riding mode changes")
    func updatesImmediatelyWhenRidingModeChanges() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 2))
        await settle()
        fixture.clock.advance(by: 1)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 3))
        await settle()

        #expect(fixture.activityClient.updateCount == 1)
        #expect(fixture.activityClient.updatedStates.last?.modeIndex == 3)
    }

    @Test("Switches from riding to charging without duplicate activity")
    func switchesFromRidingToChargingWithoutDuplicateActivity() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 3))
        await settle()
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 73))
        await settle()

        #expect(fixture.activityClient.startCount == 1)
        #expect(fixture.activityClient.updateCount == 1)
        #expect(fixture.activityClient.updatedStates.last?.mode == .charging)
        #expect(await fixture.repository.monitoringStartCount() == 1)
    }

    @Test("Ends when riding turns off")
    func endsWhenRidingTurnsOff() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(ridingTelemetry(percent: 72, mode: 3))
        await settle()
        await fixture.repository.sendTelemetry(idleTelemetry(percent: 72))
        await settle()

        #expect(fixture.activityClient.endCount == 1)
    }

    @Test("Ends and releases monitoring at charge target")
    func endsAtChargeTarget() async {
        let fixture = BikeLiveActivityControllerFixture()

        fixture.controller.start()
        await settle()
        fixture.controller.setIsSetupCompleted(true)
        fixture.controller.setCanShowLiveActivity(true)
        await fixture.repository.sendConnection(.receivingTelemetry)
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 79))
        await fixture.repository.sendBatteryHealth(chargingHealth(target: 80, current: 5))
        await settle()
        await fixture.repository.sendTelemetry(chargingTelemetry(percent: 80))
        await settle()

        #expect(fixture.activityClient.endCount == 1)
        #expect(fixture.activityClient.endedStates.last?.phase == .complete)
        #expect(await fixture.repository.monitoringStopCount() == 1)
    }

}
private func settle() async {
    await settle(milliseconds: 20)
}

private func settle(milliseconds: Int64) async {
    try? await Task.sleep(for: .milliseconds(milliseconds))
}

private extension BikeConnection {
    static let receivingTelemetry = BikeConnection(state: .receivingTelemetry(peripheralName: "Bike"))
}
