import BikeDomain
import BikeEmulator
import Testing
import TestSupport

@MainActor
struct AppChargingControllerTests {
    @Test func pendingAppliesWithoutAnyScreenAndViewSuspensionCannotResetIt() async throws {
        let fixture = try await AppChargingFixture.make()
        fixture.controller.start()
        #expect(await fixture.hub.waitForSubscriber())
        await fixture.publish(connected: false)
        #expect(await waitUntil { fixture.preferences.state.hasBike })
        fixture.preferences.setTarget(percent: 85)
        await fixture.publish(connected: true, matchesBike: false)
        #expect(await waitUntil { !fixture.preferences.state.isConnected })
        #expect(fixture.preferences.state.preferences.pendingTarget?.percent == 85)
        await fixture.publish(connected: true)
        #expect(await waitUntil { fixture.preferences.state.hasFreshConfiguration })
        #expect(await waitUntil { !fixture.preferences.state.preferences.hasPendingChanges })
        fixture.session.receive(.init())
        #expect(fixture.preferences.state.isConnected)
        #expect(fixture.preferences.state.preferences.confirmed?.maximumStateOfChargeDeciPercent == 850)
        await fixture.controller.stopAndWait()
        await fixture.repository.stop()
    }

    @Test func monitoringSurvivesScreenNavigationAndReleasesOnStop() async throws {
        let fixture = try await AppChargingFixture.make()
        fixture.controller.start()
        #expect(await fixture.hub.waitForSubscriber())
        await fixture.publish(connected: true, charger: true)
        #expect(await waitUntil { await fixture.vehicle.isMonitoring() })
        fixture.session.receive(.init())
        #expect(await fixture.vehicle.isMonitoring())
        await fixture.controller.stopAndWait()
        #expect(await fixture.vehicle.isMonitoring() == false)
        fixture.controller.start()
        #expect(await fixture.hub.waitForSubscriber())
        await fixture.publish(connected: true)
        #expect(await waitUntil { fixture.preferences.state.isConnected })
        await fixture.controller.stopAndWait()
        await fixture.repository.stop()
    }
}
