import BikeDomain
import Foundation
import SettingsDomain
import Testing
import VehicleSession

struct BikeCompanionSnapshotMapperTests {
    @Test func sendsOnlyActiveMapTraction() {
        let now = Date()
        let telemetry = BikeTelemetry(
            vin: "FENRTEST000000001", batteryLevel: .known(percent: 38), mode: .index(4),
            statusFlags: .init(isOn: true, isInGear: true),
            powerModeConfigurations: [
                0: .init(mapIndex: 0, powerTractionPercent: 99),
                3: .init(mapIndex: 3, powerTractionPercent: 12)
            ], lastUpdated: now
        )
        let source = VehicleSessionSnapshot(
            telemetry: telemetry, profile: .init(vin: "FENRTEST000000001"),
            isCanonicalTelemetryAvailable: true
        )
        let result = BikeCompanionSnapshotMapper().map(source, now: now)
        #expect(result.mapIndex == 4 && result.tractionPercent == 12)
        #expect(result.telemetryAt == now && result.batteryPercent == 38)
    }

    @Test func sendsConfiguredNameAndOffStateWithoutActiveTraction() throws {
        let now = Date()
        var settings = AppSettings()
        try settings.setPowerModeName(.init("Trail"), forVIN: "FENRTEST000000001", mapIndex: 1)
        let source = VehicleSessionSnapshot(
            telemetry: BikeTelemetry(
                mode: .index(2), statusFlags: .init(isOn: false),
                powerModeConfigurations: [1: .init(mapIndex: 1, powerTractionPercent: 20)], lastUpdated: now
            ),
            settings: settings, profile: .init(vin: "FENRTEST000000001"), isCanonicalTelemetryAvailable: true
        )
        let result = BikeCompanionSnapshotMapper().map(source, now: now)
        #expect(result.mapName == "Trail" && result.activity == .off)
        #expect(result.tractionPercent == nil)
    }

    @Test func authenticatedTelemetryDoesNotRequireTheOptionalVINDataset() {
        let now = Date()
        let source = VehicleSessionSnapshot(
            telemetry: BikeTelemetry(batteryLevel: .known(percent: 62), mode: .index(3), lastUpdated: now),
            profile: .init(vin: "FENRTEST000000001"), isCanonicalTelemetryAvailable: true
        )
        let result = BikeCompanionSnapshotMapper().map(source, now: now)
        #expect(result.bikeConnected && result.batteryPercent == 62 && result.mapIndex == 3)
    }

    @Test func changedBikeAndNoncanonicalTelemetryClearOldDashboard() {
        let now = Date()
        let telemetry = BikeTelemetry(vin: "FENRTEST000000001", batteryLevel: .known(percent: 80), lastUpdated: now)
        for source in [
            VehicleSessionSnapshot(telemetry: telemetry, profile: .init(vin: "FENRTEST000000002"),
                                   isCanonicalTelemetryAvailable: true),
            VehicleSessionSnapshot(telemetry: telemetry, profile: .init(vin: "FENRTEST000000001"),
                                   isCanonicalTelemetryAvailable: false)
        ] {
            let result = BikeCompanionSnapshotMapper().map(source, now: now)
            #expect(result.batteryPercent == nil && result.telemetryAt == nil && !result.bikeConnected)
        }
    }
}
