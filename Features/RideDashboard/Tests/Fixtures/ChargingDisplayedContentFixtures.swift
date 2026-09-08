import BikeDomain
@testable import RideDashboard
import VehicleSession

enum ChargingDisplayedContentFixtures {
    enum Change: CaseIterable {
        case none, invisibleValue, unavailable, text, unit, battery, target, time, balancing, readout, control
        case temperatureEmphasis, maximumPower, chargingPower, current, temperature, balancingCells
    }

    static func state(_ change: Change = .none) -> ChargingDashboardViewState {
        let common = DashboardMetricViewData(
            valueText: change == .text ? "2" : "1",
            unitText: change == .unit ? "changed" : "unit",
            animationValue: change == .unavailable ? nil : (change == .invisibleValue ? 1.02 : 1.01)
        )
        let changed = DashboardMetricViewData(valueText: "changed", unitText: "unit", animationValue: 1.01)
        return .init(
            batteryPercent: change == .battery ? 61 : 60,
            targetPercent: change == .target ? 90 : 100,
            estimatedTimeRemaining: change == .time ? "2 hours" : "1 hour",
            isBalancingAtFullCharge: change == .balancing,
            readout: .init(allowsControl: change != .readout),
            control: .init(isEnabled: change != .control),
            maximumPower: change == .maximumPower ? changed : common,
            chargingPower: change == .chargingPower ? changed : common,
            reportedCurrent: change == .current ? changed : common,
            batteryTemperature: change == .temperature ? changed : common,
            batteryTemperatureEmphasis: change == .temperatureEmphasis ? .warning : .normal,
            activeBalancingCells: change == .balancingCells ? changed : common
        )
    }

    static func snapshot(
        temperature: Double, vin: String = DashboardMappingSnapshots.vin, watts: Double = 1_000
    ) -> VehicleSessionSnapshot {
        let base = DashboardMappingSnapshots.charging(vin: vin, watts: watts)
        var health = base.batteryHealth
        health.temperatures = [.init(position: 1, celsius: temperature)]
        return .init(
            telemetry: base.telemetry, connection: base.connection, settings: base.settings,
            profile: base.profile, batteryHealth: health, batteryHealthMonitoringState: .active,
            hasReceivedSettings: true, hasReceivedProfile: true, isCanonicalTelemetryAvailable: true
        )
    }
}
