import BikeDomain
import Foundation

struct BikeEmulatorElectricalTelemetry {
    let power: BikePowerTelemetry
    let battery: BikeBatteryTelemetry
}

struct BikeEmulatorElectricalTelemetryContext {
    let batteryPercent: Int
    let isCharging: Bool
    let isRiding: Bool
    let tick: Int
    let date: Date
}

enum BikeEmulatorElectricalTelemetryFactory {
    static func make(
        context: BikeEmulatorElectricalTelemetryContext,
        powerCalculator: BikePowerTelemetryCalculator
    ) -> BikeEmulatorElectricalTelemetry {
        let currentRaw = context.isRiding ? ridingCurrentRaw(at: context.tick) : (
            context.isCharging ? Constants.chargingCurrentRaw : .zero
        )
        let calculation = powerCalculator.calculate(
            dcBusVolts: Constants.dcBusVolts,
            batteryCurrentAmperes: Double(currentRaw)
        )
        return BikeEmulatorElectricalTelemetry(
            power: .init(
                electricalPowerWatts: calculation.electricalPowerWatts,
                calculatedPowerUpdatedAt: context.date
            ),
            battery: .init(
                stateOfCharge: .known(percent: context.batteryPercent),
                stateOfHealth: .known(percent: Constants.healthPercent),
                dcBusRaw: Constants.dcBusRaw,
                dcBusVolts: Constants.dcBusVolts,
                currentRaw: currentRaw,
                currentAmperes: Double(currentRaw),
                positiveBMS: makeBMS(
                    dcBusRaw: Constants.dcBusRaw,
                    temperatureRaw: Constants.positiveTemperatureRaw,
                    humidityRaw: Constants.positiveHumidityRaw
                ),
                negativeBMS: makeBMS(
                    dcBusRaw: Constants.negativeDCBusRaw,
                    temperatureRaw: Constants.negativeTemperatureRaw,
                    humidityRaw: Constants.negativeHumidityRaw
                ),
                stateUpdatedAt: context.date,
                signalsUpdatedAt: context.date
            )
        )
    }

    private static func ridingCurrentRaw(at tick: Int) -> Int {
        Int((Constants.ridingCurrentOffset
            + Constants.ridingCurrentAmplitude * sin(Double(tick) * Constants.ridingCurrentWaveRadians)).rounded())
    }

    private static func makeBMS(
        dcBusRaw: Int,
        temperatureRaw: Int,
        humidityRaw: Int
    ) -> BikeBMSSignalsTelemetry {
        .init(
            dcBusRaw: dcBusRaw,
            dcBusVolts: Double(dcBusRaw) / Constants.dcBusScale,
            temperatureRaw: temperatureRaw,
            temperatureCelsius: Double(temperatureRaw) / Constants.environmentScale,
            humidityRaw: humidityRaw,
            humidityPercent: Double(humidityRaw) / Constants.environmentScale
        )
    }

    private enum Constants {
        static let healthPercent = 94
        static let dcBusRaw = 4_000
        static let dcBusVolts = 400.0
        static let negativeDCBusRaw = 3_995
        static let ridingCurrentOffset = 18.0
        static let ridingCurrentAmplitude = 30.0
        static let ridingCurrentWaveRadians = 0.45
        static let chargingCurrentRaw = -5
        static let positiveTemperatureRaw = 2_534
        static let negativeTemperatureRaw = 2_450
        static let positiveHumidityRaw = 5_012
        static let negativeHumidityRaw = 4_899
        static let dcBusScale = 10.0
        static let environmentScale = 100.0
    }
}
