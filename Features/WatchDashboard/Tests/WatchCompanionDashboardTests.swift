import Foundation
import Testing
import TestSupport
import WatchCompanionDomain
@testable import WatchDashboard

@MainActor
struct WatchCompanionDashboardTests {
    @Test func offStateTakesPriorityOverLastSelectedMap() {
        let now = Date()
        let snapshot = CompanionSnapshot(
            generatedAt: now, telemetryAt: now, bikeConnected: true,
            batteryPercent: 38, mapIndex: 2, mapName: "Trail", activity: .off, tractionPercent: 20
        )
        let state = WatchDashboardViewStateMapper(freshnessInterval: 15)
            .map(.init(snapshot: snapshot, isReachable: true), now: now)
        #expect(state.map == "OFF" && !state.showsMap)
        #expect(state.traction == "--")
        #expect(state.batteryEmphasis == .warning)
    }

    @Test(arguments: [20, 21, 38, 50, 51]) func batteryUsesTheSameThresholdsAsPhone(percent: Int) {
        let now = Date()
        let snapshot = CompanionSnapshot(generatedAt: now, telemetryAt: now, batteryPercent: percent)
        let state = WatchDashboardViewStateMapper(freshnessInterval: 15).map(.init(snapshot: snapshot), now: now)
        if percent <= 20 {
            #expect(state.batteryEmphasis == .critical)
        } else if percent <= 50 {
            #expect(state.batteryEmphasis == .warning)
        } else {
            #expect(state.batteryEmphasis == .positive)
        }
    }

    @Test func mapUsesNameFromPhoneWhenRiding() {
        let now = Date()
        let snapshot = CompanionSnapshot(
            generatedAt: now, telemetryAt: now, bikeConnected: true,
            mapIndex: 2, mapName: "Trail", activity: .riding
        )
        let state = WatchDashboardViewStateMapper(freshnessInterval: 15)
            .map(.init(snapshot: snapshot, isReachable: true), now: now)
        #expect(state.showsMap && state.map == "Trail")
    }

    @Test func staleDataRemainsVisibleButNeverAppearsLive() {
        let now = Date()
        let mapper = WatchDashboardViewStateMapper(freshnessInterval: 15)
        let snapshot = CompanionSnapshot(
            generatedAt: now, telemetryAt: now.addingTimeInterval(-60),
            bikeConnected: true, batteryPercent: 38, mapIndex: 4, activity: .riding, tractionPercent: 12
        )
        let state = mapper.map(.init(snapshot: snapshot, isReachable: true), now: now)
        #expect(state.hasData && state.isStale)
        #expect(state.batteryPercent == 38)
        #expect(state.map == "4")
        #expect(state.updatedAt == snapshot.telemetryAt)
    }

    @Test func phoneLossImmediatelyMarksFreshDataAsStale() {
        let now = Date()
        let snapshot = CompanionSnapshot(generatedAt: now, telemetryAt: now, bikeConnected: true)
        let mapper = WatchDashboardViewStateMapper(freshnessInterval: 15)
        #expect(!mapper.map(.init(snapshot: snapshot, isReachable: true), now: now).isStale)
        #expect(mapper.map(.init(snapshot: snapshot, isReachable: false), now: now).isStale)
        #expect(mapper.map(.init(snapshot: snapshot, isReachable: true), now: now.addingTimeInterval(16)).isStale)
    }

    @Test func missingTractionDoesNotBecomeZero() {
        let now = Date()
        let snapshot = CompanionSnapshot(generatedAt: now, telemetryAt: now, bikeConnected: true)
        let state = WatchDashboardViewStateMapper(freshnessInterval: 15)
            .map(.init(snapshot: snapshot, isReachable: true), now: now)
        #expect(state.traction == "--")
    }

    @Test func chargingUsesPhoneValuesAndETA() {
        let now = Date()
        let snapshot = CompanionSnapshot(
            generatedAt: now, telemetryAt: now, bikeConnected: true, isCharging: true,
            batteryPercent: 88, chargingPowerWatts: 1_000, chargingCurrentAmperes: 2.6,
            chargeRemainingSeconds: 3_060
        )
        let state = WatchDashboardViewStateMapper(freshnessInterval: 15)
            .map(.init(snapshot: snapshot, isReachable: true), now: now)
        #expect(state.isCharging)
        #expect(state.batteryPercent == 88)
        #expect(state.chargingPower != "--")
        #expect(state.chargeETA != nil)
    }

    @Test func restartingDoesNotKeepOldObserversOrDuplicateStart() async {
        let session = CompanionSessionSpy()
        let model = WatchDashboardViewModel(
            observe: .init(session: session), mapper: .init(freshnessInterval: 15), now: Date.init
        )
        model.start()
        model.start()
        #expect(session.observations == 1)
        model.stop()
        #expect(await waitUntil { session.subscriberCount == 0 })
        model.start()
        #expect(session.observations == 2)
        let now = Date()
        session.send(.init(snapshot: .init(
            generatedAt: now, telemetryAt: now, bikeConnected: true, batteryPercent: 73
        ), isReachable: true))
        #expect(await waitUntil { model.viewState.batteryPercent == 73 })
        model.stop()
        #expect(await waitUntil { session.subscriberCount == 0 })
        session.send(.init())
        #expect(model.viewState.batteryPercent == 73)
    }

    @Test func droppingTheDashboardCancelsItsSubscriptions() async {
        let session = CompanionSessionSpy()
        var model: WatchDashboardViewModel? = WatchDashboardViewModel(
            observe: .init(session: session), mapper: .init(freshnessInterval: 15), now: Date.init
        )
        weak var releasedModel = model
        model?.start()
        #expect(await waitUntil { session.subscriberCount == 1 })
        model = nil
        #expect(await waitUntil { releasedModel == nil && session.subscriberCount == 0 })
    }

}
