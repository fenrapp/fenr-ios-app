import BikeDomain
import ChargeControl
import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing
import VehicleSession

struct DashboardMappingCacheTests {
    @Test("IMU, unrelated settings and timestamp-only updates reuse the riding presentation")
    func ridingInputsAvoidUnrelatedMapping() {
        let recorder = DashboardMapperCallRecorder()
        var cache = DashboardPresentationCache<RideDashboardMappingInput, Int>()
        let original = DashboardMappingSnapshots.ride()
        var unrelatedSettings = original.settings
        unrelatedSettings.liveActivities.isEnabled = false
        var telemetry = original.telemetry
        telemetry.lastUpdated = Date(timeIntervalSinceReferenceDate: 99)
        let timestampOnly = VehicleSessionSnapshot(
            telemetry: telemetry, connection: original.connection, settings: original.settings,
            profile: original.profile, resolvedSpeedKilometersPerHour: original.resolvedSpeedKilometersPerHour
        )
        let snapshots = [
            original, DashboardMappingSnapshots.ride(motion: .init(rollDegrees: 45, availability: .available)),
            DashboardMappingSnapshots.ride(settings: unrelatedSettings), timestampOnly
        ]
        for snapshot in snapshots {
            _ = cache.value(for: RideDashboardMappingInput(snapshot: snapshot)) {
                recorder.record("render")
                return recorder.count("render")
            }
        }
        #expect(recorder.count("render") == 1)
        _ = cache.value(for: RideDashboardMappingInput(snapshot: DashboardMappingSnapshots.ride(speed: 30))) {
            recorder.record("render")
            return recorder.count("render")
        }
        #expect(recorder.count("render") == 2)
    }

    @Test("Charging mapping ignores health timestamps but preserves availability and optimistic confirmation")
    func chargingInputsPreserveAvailabilityAndControlChanges() {
        let recorder = DashboardMapperCallRecorder()
        var cache = DashboardPresentationCache<ChargingDashboardMappingInput, Int>()
        var health = ChargingObservationData.chargingHealth
        let states = [
            ChargeControlState(phase: .ready),
            ChargeControlState(selectedWatts: 1_500, phase: .updating),
            ChargeControlState(selectedWatts: 1_500, confirmedWatts: 1_500, status: .confirmed(.powerWatts(1_500)))
        ]
        for state in states {
            let key = ChargingDashboardMappingInput(
                configuration: nil, batteryPercent: 62, isChargerConnected: true,
                batteryHealth: health, chargeControl: state
            )
            _ = cache.value(for: key) { recorder.record("render"); return recorder.count("render") }
        }
        #expect(recorder.count("render") == 3)
        for timestamp in [1.0, 2.0] {
            health.lastUpdated = Date(timeIntervalSinceReferenceDate: timestamp)
            let key = ChargingDashboardMappingInput(
                configuration: nil, batteryPercent: 62, isChargerConnected: true,
                batteryHealth: health, chargeControl: states[2]
            )
            _ = cache.value(for: key) { recorder.record("render"); return recorder.count("render") }
        }
        #expect(recorder.count("render") == 4)
    }
}
