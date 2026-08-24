import BikeDomain
import Foundation

func chargingTelemetry(percent: Int) -> BikeTelemetry {
    BikeTelemetry(
        vin: "FENRTEST000000001",
        batteryLevel: .known(percent: percent),
        statusFlags: .init(isCharging: true),
        lastUpdated: .testNow
    )
}

func idleTelemetry(percent: Int) -> BikeTelemetry {
    BikeTelemetry(
        vin: "FENRTEST000000001",
        batteryLevel: .known(percent: percent),
        statusFlags: .init(isOn: false),
        lastUpdated: .testNow
    )
}

func ridingTelemetry(percent: Int, mode: Int) -> BikeTelemetry {
    BikeTelemetry(
        vin: "FENRTEST000000001",
        batteryLevel: .known(percent: percent),
        mode: .index(mode),
        speed: .known(kmh: 48, kmhX10: 480),
        statusFlags: .init(isOn: true, isInGear: true),
        lastUpdated: .testNow
    )
}

func chargingHealth(target: Int, current: Double) -> BikeBatteryHealth {
    BikeBatteryHealth(
        dcBusVoltage: .known(volts: 390),
        chargeState: .charging,
        chargingStatus: .init(
            requestedCurrentAmperes: current,
            reportedCurrentAmperes: current,
            maximumCurrentAmperes: 10,
            maximumPowerWatts: 3_000,
            targetCellVoltageVolts: 4.2,
            maximumStateOfChargePercent: target
        )
    )
}

private extension Date {
    static let testNow = Date(timeIntervalSinceReferenceDate: 0)
}
