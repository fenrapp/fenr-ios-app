import BikeDomain
import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing
import TestSupport

@MainActor
struct DashboardMappingViewModelTests {
    @Test("Invalidating the riding session releases its cached mapper before restarting")
    func ridingInvalidationStartsFreshMapping() async throws {
        let recorder = DashboardMapperCallRecorder()
        let session = RideDashboardVehicleSession()
        let model = DashboardMappingTestFactory.ride(recorder: recorder, session: session)
        defer { model.stopObserving() }
        model.startObserving()
        await session.send(DashboardMappingSnapshots.ride())
        try #require(await waitUntil { model.viewState.continuityPhase == .live })
        let initialBuilds = recorder.count("rideMapper")
        model.invalidateSession()
        #expect(!model.viewState.hasTelemetry)
        model.startObserving()
        try #require(await waitUntil { model.viewState.continuityPhase == .live })
        #expect(recorder.count("rideMapper") == initialBuilds + 1)
    }

    @Test("Stopping charging starts a fresh mapping configuration on restart")
    func chargingStopStartsFreshMapping() async throws {
        let recorder = DashboardMapperCallRecorder()
        let session = ChargingDashboardVehicleSession()
        let fixture = DashboardMappingTestFactory.charging(recorder: recorder, session: session)
        defer { fixture.model.stop() }
        fixture.model.start()
        await session.send(DashboardMappingSnapshots.charging())
        try #require(await waitUntil { fixture.model.viewState.control.isEnabled })
        let initialBuilds = recorder.count("chargingMapper")
        fixture.model.stop()
        #expect(!fixture.model.viewState.control.isEnabled)
        fixture.model.start()
        await session.send(DashboardMappingSnapshots.charging())
        try #require(await waitUntil { fixture.model.viewState.control.isEnabled })
        #expect(recorder.count("chargingMapper") == initialBuilds + 1)
        await fixture.control.stopAndWait()
    }

    @Test("Riding reuses its measurement mapper and invalidates units and VIN without losing canonical transitions")
    func ridingCachesConfigurationAndProcessesCanonicalState() async throws {
        let recorder = DashboardMapperCallRecorder()
        let session = RideDashboardVehicleSession()
        let model = DashboardMappingTestFactory.ride(recorder: recorder, session: session)
        defer { model.stopObserving() }
        model.startObserving()
        await session.send(DashboardMappingSnapshots.ride())
        try #require(await waitUntil { model.viewState.continuityPhase == .live })
        let initialBuilds = recorder.count("rideMapper")
        await session.send(DashboardMappingSnapshots.ride(motion: .init(rollDegrees: 45, availability: .available)))
        await session.send(DashboardMappingSnapshots.ride(speed: 30))
        try #require(await waitUntil { model.viewState.speedometer.valueText == "30" })
        #expect(recorder.count("rideMapper") == initialBuilds)
        await session.send(DashboardMappingSnapshots.ride(speed: 30, canonical: false))
        try #require(await waitUntil { model.viewState.continuityPhase == .recovering })
        await session.send(DashboardMappingSnapshots.ride(speed: 30))
        try #require(await waitUntil { model.viewState.continuityPhase == .live })
        #expect(recorder.count("rideMapper") == initialBuilds)
        let imperial = AppSettings(measurementSystem: .imperial)
        await session.send(DashboardMappingSnapshots.ride(settings: imperial))
        try #require(await waitUntil { model.viewState.speedometer.unit == "mph" })
        #expect(recorder.count("rideMapper") == initialBuilds + 1)
        await session.send(DashboardMappingSnapshots.ride(settings: imperial, vin: DashboardMappingSnapshots.otherVIN))
        try #require(await waitUntil { recorder.count("rideMapper") == initialBuilds + 2 })
        #expect(await waitUntil { model.viewState.continuityPhase == .live })
    }

    @Test("Charging caches its mapper while still confirming writes and resetting noncanonical controls")
    func chargingCachingPreservesConfirmation() async throws {
        let recorder = DashboardMapperCallRecorder()
        let session = ChargingDashboardVehicleSession()
        let fixture = DashboardMappingTestFactory.charging(recorder: recorder, session: session)
        defer { fixture.model.stop() }
        fixture.model.start()
        await session.send(DashboardMappingSnapshots.charging())
        try #require(await waitUntil { fixture.model.viewState.control.isEnabled })
        #expect(recorder.count("chargingMapper") == 1)
        fixture.model.setChargePowerLimit(watts: 1_500)
        try #require(await waitUntil { fixture.control.state.status == .confirming(.powerWatts(1_500)) })
        await session.send(DashboardMappingSnapshots.charging(
            motion: .init(pitchDegrees: 10, availability: .available)
        ))
        #expect(!fixture.control.state.canAcceptInput)
        await session.send(DashboardMappingSnapshots.charging(watts: 1_500))
        try #require(await waitUntil {
            fixture.control.state.status == .confirmed(.powerWatts(1_500))
                && fixture.model.viewState.control.isEnabled
        })
        #expect(recorder.count("chargingMapper") == 1)
        #expect(await fixture.repository.powerWrites == [1_500])
        #expect(await fixture.repository.targetWrites.isEmpty)
        #expect(fixture.model.viewState.control.target.selected == 100)
        await session.send(DashboardMappingSnapshots.charging(watts: 1_500, canonical: false))
        try #require(await waitUntil { !fixture.model.viewState.control.isEnabled })
        await session.send(DashboardMappingSnapshots.charging(watts: 1_500))
        try #require(await waitUntil { fixture.model.viewState.control.isEnabled })
        #expect(recorder.count("chargingMapper") == 1)
        var settings = AppSettings(measurementSystem: .imperial)
        await session.send(DashboardMappingSnapshots.charging(settings: settings, watts: 1_500))
        try #require(await waitUntil { recorder.count("chargingMapper") == 2 })
        settings.setBatteryPackCapacity(.sixPointEightKilowattHours, forVIN: DashboardMappingSnapshots.vin)
        await session.send(DashboardMappingSnapshots.charging(settings: settings, watts: 1_500))
        try #require(await waitUntil { recorder.count("chargingMapper") == 3 })
        await session.send(DashboardMappingSnapshots.charging(
            settings: settings, vin: DashboardMappingSnapshots.otherVIN
        ))
        try #require(await waitUntil { recorder.count("chargingMapper") == 4 })
        await fixture.control.stopAndWait()
    }
}
