import BikeDomain
import SettingsDomain

public struct DashboardProgressBarMapper: Sendable {
    public init() {}

    public func layout(for thickness: DashboardProgressBarThickness) -> DashboardProgressBarLayout {
        switch thickness {
        case .regular: .regular
        case .thick: .init(trackHeight: 6, energyHeight: 10, centerMarkerWidth: 3)
        }
    }

    public func map(
        mode: DashboardProgressBarMode,
        speedProgress: Double,
        telemetry: BikeTelemetry,
        hasTelemetry: Bool,
        measurementMapper: RideDashboardMeasurementMapper
    ) -> DashboardProgressBarViewData {
        switch mode {
        case .hidden:
            return .hidden
        case .speed:
            return .speed(progress: speedProgress)
        case .energy:
            break
        }
        guard
            hasTelemetry,
            let powerWatts = telemetry.powerTelemetry.electricalPowerWatts,
            powerWatts.isFinite,
            abs(powerWatts) > Constants.powerNeutralDeadbandWatts
        else {
            return .neutralEnergy
        }

        let power = measurementMapper.power(watts: abs(powerWatts))
        let powerText = measurementMapper.number(power.value, fractionDigits: 1)
        if powerWatts < .zero {
            guard
                let regenerativeBrakingPercent = telemetry.activePowerModeConfiguration?
                    .regenerativeBrakingPercent,
                regenerativeBrakingPercent.isFinite,
                regenerativeBrakingPercent > .zero
            else {
                return .neutralEnergy
            }
            let configuredRegenerationProgress = min(
                regenerativeBrakingPercent / Constants.maximumRegenerationPercentage,
                1
            )
            let measuredRegenerationProgress = min(
                abs(powerWatts) / Constants.maximumRegenerationPowerWatts,
                1
            )
            return .energy(
                regenerationProgress: min(
                    measuredRegenerationProgress,
                    configuredRegenerationProgress
                ),
                consumptionProgress: .zero,
                accessibilityLabel: rideDashboardLocalized(
                    .rideDashboardAccessibilityRegenerating(powerText, power.unit)
                )
            )
        }

        let maximumHorsepower = Double(
            telemetry.activePowerModeConfiguration?.horsepower
                ?? fallbackMaximumHorsepower(for: telemetry.detectedPowerTier)
        )
        let currentHorsepower = telemetry.powerTelemetry.starkMotorPowerHorsepower ?? .zero
        let consumptionProgress = maximumHorsepower > .zero
            ? min(max(currentHorsepower / maximumHorsepower, .zero), 1)
            : .zero
        return .energy(
            regenerationProgress: .zero,
            consumptionProgress: consumptionProgress,
            accessibilityLabel: rideDashboardLocalized(.rideDashboardAccessibilityConsuming(powerText, power.unit))
        )
    }

    private func fallbackMaximumHorsepower(for tier: BikeDetectedPowerTier) -> Int {
        switch tier {
        case .standardBaseline: Constants.standardMaximumHorsepower
        case .alpha: Constants.alphaMaximumHorsepower
        }
    }

    private enum Constants {
        static let maximumRegenerationPowerWatts = 10_000.0
        static let maximumRegenerationPercentage = 100.0
        static let powerNeutralDeadbandWatts = 250.0
        static let standardMaximumHorsepower = 60
        static let alphaMaximumHorsepower = 80
    }
}
