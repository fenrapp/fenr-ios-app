import BikeDomain
import SettingsDomain

public struct DashboardTemperatureSummaryMapper: Sendable {
    public init() {}

    func map(
        _ telemetry: BikeTelemetry,
        mode: DashboardTemperatureDisplayMode,
        using measurementMapper: RideDashboardMeasurementMapper
    ) -> RideDashboardViewState.TemperatureSummary {
        guard mode.isEnabled else { return .init() }
        let batteryTemperatures = [
            telemetry.batteryTelemetry.positiveBMS?.temperatureCelsius,
            telemetry.batteryTelemetry.negativeBMS?.temperatureCelsius
        ]
        return .init(
            batteryTemperatureText: mode.includesBattery
                ? temperatureText(
                    batteryTemperatures.compactMap { $0 }.filter(\.isFinite).max(),
                    measurementMapper: measurementMapper
                )
                : nil,
            inverterTemperatureText: mode.includesInverter
                ? temperatureText(
                    telemetry.inverterTemperaturesCelsius.compactMap { $0 }.filter(\.isFinite).max(),
                    measurementMapper: measurementMapper
                )
                : nil
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
