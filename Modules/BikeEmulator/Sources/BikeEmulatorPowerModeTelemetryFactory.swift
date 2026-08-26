import BikeDomain

enum BikeEmulatorPowerModeTelemetryFactory {
    static func detectedTier(preset: BikeEmulatorPowerModePreset) -> BikeDetectedPowerTier {
        switch preset {
        case .alpha, .mismatch:
            .alpha(evidence: [.powerAboveStandard, .tractionControlConfigured])
        case .standard, .claimedAlpha, .partial, .failure:
            .standardBaseline
        }
    }

    static func configurations(
        preset: BikeEmulatorPowerModePreset,
        activeMapNumber: Int
    ) -> [Int: BikePowerModeConfiguration] {
        switch preset {
        case .failure:
            return [:]
        case .partial:
            let configurationIndex = activeMapNumber - 1
            return [configurationIndex: .init(mapIndex: configurationIndex, powerTractionPercent: 20)]
        case .standard, .claimedAlpha:
            return configurations(
                horsepower: [20, 30, 40, 50, 60],
                regenerativeBraking: [10, 20, 30, 40, 50]
            )
        case .alpha, .mismatch:
            return configurations(
                horsepower: [20, 35, 50, 65, 80],
                regenerativeBraking: [10, 20, 30, 40, 50],
                powerTraction: [0, 10, 20, 30, 40],
                brakingTraction: [0, 5, 10, 15, 20]
            )
        }
    }

    private static func configurations(
        horsepower: [Int],
        regenerativeBraking: [Double],
        powerTraction: [Double]? = nil,
        brakingTraction: [Double]? = nil
    ) -> [Int: BikePowerModeConfiguration] {
        Dictionary(uniqueKeysWithValues: horsepower.indices.map { index in
            (index, BikePowerModeConfiguration(
                mapIndex: index,
                horsepower: horsepower[index],
                regenerativeBrakingPercent: regenerativeBraking[index],
                powerTractionPercent: powerTraction?[index],
                brakingTractionPercent: brakingTraction?[index]
            ))
        })
    }
}
