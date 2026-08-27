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
            batteryCurrentCandidateAmperes: Double(currentRaw)
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
                currentCandidateAmperes: Double(currentRaw),
                positiveBMS: makeBMS(
                    voltageCandidateRaw: Constants.positiveVoltageCandidateRaw,
                    temperatureRaw: Constants.positiveTemperatureRaw,
                    humidityRaw: Constants.positiveHumidityRaw
                ),
                negativeBMS: makeBMS(
                    voltageCandidateRaw: Constants.negativeVoltageCandidateRaw,
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
        voltageCandidateRaw: Int,
        temperatureRaw: Int,
        humidityRaw: Int
    ) -> BikeBMSSignalsTelemetry {
        .init(
            voltageCandidateRaw: voltageCandidateRaw,
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
        static let positiveVoltageCandidateRaw = 408
        static let negativeVoltageCandidateRaw = 403
        static let ridingCurrentOffset = 18.0
        static let ridingCurrentAmplitude = 30.0
        static let ridingCurrentWaveRadians = 0.45
        static let chargingCurrentRaw = -5
        static let positiveTemperatureRaw = 2_534
        static let negativeTemperatureRaw = 2_450
        static let positiveHumidityRaw = 5_012
        static let negativeHumidityRaw = 4_899
        static let environmentScale = 100.0
    }
}
