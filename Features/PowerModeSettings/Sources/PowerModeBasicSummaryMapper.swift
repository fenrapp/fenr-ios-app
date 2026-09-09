import BikeDomain

struct PowerModeBasicSummaryMapper {
    func basicTelemetry(
        _ telemetry: BikeTelemetry,
        configurations: [Int: BikeAdvancedPowerModeConfiguration],
        drafts: [Int: PowerModeCurveDraft]
    ) -> BikeTelemetry {
        var value = telemetry
        for (map, confirmed) in configurations {
            let configuration = drafts[map]?.configuration ?? confirmed
            value.powerModeConfigurations[map]?.horsepower = Int((Double(configuration.torqueRaw) / 1.25).rounded())
            value.powerModeConfigurations[map]?.regenerativeBrakingPercent = Double(configuration.regenerationRaw)
            value.powerModeConfigurations[map]?.powerTractionPercent = configuration.powerTractionRaw.map {
                Double($0) / 10
            }
            value.powerModeConfigurations[map]?.brakingTractionPercent = configuration.brakingTractionRaw.map {
                Double($0) / 10
            }
        }
        return value
    }
}
