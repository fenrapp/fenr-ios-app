import BikeDomain

public struct DashboardTemperatureSummaryMapper: Sendable {
    public init() {}

    func map(
        telemetry: BikeTelemetry,
        isVisible: Bool,
        measurementMapper: RideDashboardMeasurementMapper
    ) -> RideDashboardViewState.TemperatureSummary {
        guard isVisible else { return .init() }
        let batteryTemperatures = [
            telemetry.batteryTelemetry.positiveBMS?.temperatureCelsius,
            telemetry.batteryTelemetry.negativeBMS?.temperatureCelsius
        ]
        return .init(
            batteryTemperatureText: temperatureText(
                batteryTemperatures.compactMap { $0 }.filter(\.isFinite).max(),
                measurementMapper: measurementMapper
            ),
            inverterTemperatureText: temperatureText(
                telemetry.inverterTemperaturesCelsius.compactMap { $0 }.filter(\.isFinite).max(),
                measurementMapper: measurementMapper
            )
        )
    }

    private func temperatureText(
        _ celsius: Double?,
        measurementMapper: RideDashboardMeasurementMapper
    ) -> String? {
        guard let celsius else { return nil }
        let temperature = measurementMapper.temperature(celsius: celsius)
        return measurementMapper.number(temperature.value, fractionDigits: .zero) + temperature.unit
    }
}
