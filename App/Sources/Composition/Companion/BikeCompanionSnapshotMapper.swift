import BikeDomain
import Foundation
import VehicleSession
import WatchCompanionDomain

struct BikeCompanionSnapshotMapper {
    func map(_ source: VehicleSessionSnapshot, now: Date) -> CompanionSnapshot {
        let telemetry = source.telemetry
        // The optional VIN dataset may be absent even after this session authenticates.
        let matchesProfile = source.profile.map { telemetry.vin.isEmpty || $0.vin == telemetry.vin } ?? false
        let available = source.isCanonicalTelemetryAvailable && matchesProfile
        guard available else { return CompanionSnapshot(generatedAt: now) }
        let charging = telemetry.runState == .charging
        let status = source.batteryHealth.chargingStatus
        return CompanionSnapshot(
            generatedAt: now,
            telemetryAt: telemetry.lastUpdated,
            bikeConnected: true,
            isCharging: charging,
            batteryPercent: telemetry.batteryLevel.percent,
            mapIndex: telemetry.mode.powerModeConfigurationIndex.map { $0 + 1 },
            mapName: telemetry.mode.powerModeConfigurationIndex.flatMap {
                source.settings.powerModeName(forVIN: source.profile?.vin, mapIndex: $0)?.value
            },
            activity: activity(telemetry.runState),
            tractionPercent: telemetry.runState == .on
                ? telemetry.activePowerModeConfiguration?.powerTractionPercent : nil,
            chargingPowerWatts: charging ? status.map { Double($0.maximumPowerWatts) } : nil,
            chargingCurrentAmperes: charging ? status?.reportedCurrentAmperes : nil,
            chargeRemainingSeconds: charging ? remainingSeconds(source) : nil
        )
    }

    private func activity(_ state: BikeRunState) -> CompanionSnapshot.Activity {
        switch state {
        case .off: .off
        case .neutral: .neutral
        case .on: .riding
        case .charging: .charging
        case .crawlForward, .crawlReverse: .crawl
        case .unknown: .unknown
        }
    }

    private func remainingSeconds(_ source: VehicleSessionSnapshot) -> Double? {
        guard let status = source.batteryHealth.chargingStatus,
              let percent = source.telemetry.batteryLevel.percent,
              let voltage = source.batteryHealth.dcBusVoltage.volts,
              voltage > 0, status.reportedCurrentAmperes > 0,
              percent < status.maximumStateOfChargePercent else { return nil }
        let energy = Double(status.maximumStateOfChargePercent - percent) / 100
            * source.settings.batteryPackCapacity.wattHours
        let seconds = energy / (voltage * status.reportedCurrentAmperes) * 3_600
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }
}
