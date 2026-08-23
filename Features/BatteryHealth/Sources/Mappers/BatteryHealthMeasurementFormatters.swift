import Foundation

@MainActor
public final class BatteryHealthMeasurementFormatters {
    private let voltageFormatter: MeasurementFormatter
    private let temperatureFormatter: MeasurementFormatter
    private let currentFormatter: MeasurementFormatter
    private let powerFormatter: MeasurementFormatter
    private let temperatureUnit: UnitTemperature

    public init(
        voltageFormatter: MeasurementFormatter,
        temperatureFormatter: MeasurementFormatter,
        currentFormatter: MeasurementFormatter,
        powerFormatter: MeasurementFormatter,
        temperatureUnit: UnitTemperature
    ) {
        self.voltageFormatter = voltageFormatter
        self.temperatureFormatter = temperatureFormatter
        self.currentFormatter = currentFormatter
        self.powerFormatter = powerFormatter
        self.temperatureUnit = temperatureUnit
    }

    func voltage(_ value: Double) -> String {
        voltageFormatter.string(
            from: Measurement(value: value, unit: UnitElectricPotentialDifference.volts)
        )
    }

    func temperature(celsius: Double) -> String {
        temperatureFormatter.string(
            from: Measurement(value: celsius, unit: UnitTemperature.celsius).converted(to: temperatureUnit)
        )
    }

    func current(amperes: Double) -> String {
        currentFormatter.string(from: Measurement(value: amperes, unit: UnitElectricCurrent.amperes))
    }

    func power(watts: Double) -> String {
        powerFormatter.string(from: Measurement(value: watts, unit: UnitPower.watts))
    }
}
