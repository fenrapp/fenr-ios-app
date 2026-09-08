import BikeDomain
import ChargeControl
import SettingsDomain

struct ChargingDashboardMappingInput: Equatable {
    struct Configuration: Equatable {
        let measurementSystem: MeasurementSystem
        let capacity: BatteryPackCapacity
        let vin: String?

        init(settings: AppSettings, vin: String?) {
            measurementSystem = settings.measurementSystem
            capacity = settings.batteryPackCapacity(forVIN: vin)
            self.vin = vin
        }
    }

    let configuration: Configuration?
    let batteryPercent: Int?
    let isChargerConnected: Bool
    let batteryHealth: BikeBatteryHealth
    let chargeControl: ChargeControlState

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.configuration == rhs.configuration
            && lhs.batteryPercent == rhs.batteryPercent
            && lhs.isChargerConnected == rhs.isChargerConnected
            && lhs.chargeControl == rhs.chargeControl
            && lhs.batteryHealth.chargingStatus == rhs.batteryHealth.chargingStatus
            && lhs.batteryHealth.dcBusVoltage.volts == rhs.batteryHealth.dcBusVoltage.volts
            && lhs.batteryHealth.chargeState == rhs.batteryHealth.chargeState
            && lhs.batteryHealth.temperatures == rhs.batteryHealth.temperatures
            && lhs.batteryHealth.balancingCellIndexes.count == rhs.batteryHealth.balancingCellIndexes.count
            && (lhs.batteryHealth.lastUpdated != nil) == (rhs.batteryHealth.lastUpdated != nil)
    }
}
