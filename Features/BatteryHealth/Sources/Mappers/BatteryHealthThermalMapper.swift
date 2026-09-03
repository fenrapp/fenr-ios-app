import BikeDomain

extension BikeBatteryHealthToViewStateMapper {
    func thermalViewData(
        health: BikeBatteryHealth,
        analysis: BatteryHealthAnalysis
    ) -> BatteryHealthThermalViewData {
        guard let range = analysis.batteryTemperatures else {
            return .init()
        }
        let domain = thermalDisplayDomain(
            minimum: range.minimumCelsius,
            maximum: range.maximumCelsius
        )
        return .init(
            metrics: thermalMetrics(for: analysis),
            sensors: temperatureViewData(for: health, analysis: analysis),
            valueRangeCelsius: range.minimumCelsius ... range.maximumCelsius,
            averageCelsius: range.averageCelsius,
            displayDomainCelsius: domain,
            emphasis: temperatureEmphasis(analysis.severity)
        )
    }

    func thermalMetrics(for analysis: BatteryHealthAnalysis) -> [BatteryHealthMetricViewData] {
        guard let values = analysis.batteryTemperatures else { return [] }
        return [
            metric("minimum", BatteryHealthText.minimum, formatter.temperature(celsius: values.minimumCelsius)),
            metric("average", BatteryHealthText.average, formatter.temperature(celsius: values.averageCelsius)),
            metric("maximum", BatteryHealthText.maximum, formatter.temperature(celsius: values.maximumCelsius))
        ]
    }

    func temperatureViewData(
        for health: BikeBatteryHealth,
        analysis: BatteryHealthAnalysis
    ) -> [BatteryTemperatureViewData] {
        let emphasis = temperatureEmphasis(analysis.severity)
        return health.temperatures.map {
            BatteryTemperatureViewData(
                position: $0.position,
                value: formatter.temperature(celsius: $0.celsius),
                emphasis: emphasis
            )
        }
    }

    func temperatureEmphasis(_ severity: BatteryHealthSeverity) -> BatteryHealthStatusEmphasis {
        switch severity {
        case .unknown: .neutral
        case .healthy: .positive
        case .attention: .warning
        case .critical: .critical
        }
    }

    func thermalDisplayDomain(minimum: Double, maximum: Double) -> ClosedRange<Double> {
        let lower = (minimum / Constants.thermalDomainStep).rounded(.down) * Constants.thermalDomainStep
        let upper = (maximum / Constants.thermalDomainStep).rounded(.up) * Constants.thermalDomainStep
        guard lower == upper else { return lower ... upper }
        return (lower - Constants.thermalDomainPadding) ... (upper + Constants.thermalDomainPadding)
    }
}
