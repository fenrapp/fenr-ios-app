import DesignSystem
import SwiftUI

struct DashboardSystemHealthThermalCard: View {
    let state: DashboardSystemHealthViewData

    var body: some View {
        DashboardAdaptiveCardSurface {
            VStack(spacing: Constants.spacing) {
                DashboardSystemHealthHeader(
                    title: rideDashboardLocalized(.rideDashboardSystemHealthThermalTitle),
                    state: state
                )
                thermalSection(
                    title: rideDashboardLocalized(.rideDashboardSystemHealthBattery),
                    systemImage: "battery.100percent",
                    range: state.batteryThermalRange,
                    usesBatteryThresholds: true
                )
                thermalSection(
                    title: rideDashboardLocalized(.rideDashboardSystemHealthInverter),
                    systemImage: "bolt.horizontal.fill",
                    range: state.inverterThermalRange,
                    usesBatteryThresholds: false
                )
            }
            .dynamicTypeSize(...DynamicTypeSize.large)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private func thermalSection(
        title: String,
        systemImage: String,
        range: DashboardSystemHealthViewData.ThermalRange?,
        usesBatteryThresholds: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(DesignColor.secondaryText)
            if let range {
                RangeGauge(
                    valueRange: range.minimumCelsius ... range.maximumCelsius,
                    average: range.averageCelsius,
                    domain: Constants.temperatureDomain,
                    gradientStops: usesBatteryThresholds ? Constants.batteryStops : nil,
                    markerColor: usesBatteryThresholds ? DesignColor.primaryText : DesignColor.informational
                )
                HStack(spacing: DesignSpace.extraSmall) {
                    thermalMetric(
                        rideDashboardLocalized(.rideDashboardSystemHealthThermalMinimum),
                        range.minimumText,
                        alignment: .leading
                    )
                    thermalMetric(
                        rideDashboardLocalized(.rideDashboardSystemHealthThermalAverage),
                        range.averageText,
                        alignment: .center
                    )
                    thermalMetric(
                        rideDashboardLocalized(.rideDashboardSystemHealthThermalMaximum),
                        range.maximumText,
                        alignment: .trailing
                    )
                }
            } else {
                Text(.rideDashboardSystemHealthThermalNoData)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(DesignColor.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(DesignSpace.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignColor.elevatedSurface, in: RoundedRectangle(cornerRadius: DesignRadius.medium))
    }

    private func thermalMetric(_ title: String, _ value: String, alignment: Alignment) -> some View {
        VStack(alignment: horizontalAlignment(alignment), spacing: DesignSpace.extraExtraSmall) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.secondaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func horizontalAlignment(_ alignment: Alignment) -> HorizontalAlignment {
        if alignment == .leading { return .leading }
        if alignment == .trailing { return .trailing }
        return .center
    }

    private var accessibilityText: String {
        rideDashboardLocalized(.rideDashboardSystemHealthThermalAccessibility(
            state.batteryTemperatureText,
            state.inverterTemperatureText
        ))
    }

    private enum Constants {
        static let spacing: CGFloat = 8
        static let temperatureDomain = -10.0 ... 100.0
        static let batteryStops: [Gradient.Stop] = [
            .init(color: DesignColor.critical.opacity(0.5), location: 0.00),
            .init(color: DesignColor.warning.opacity(0.5), location: 0.13),
            .init(color: DesignColor.positive.opacity(0.35), location: 0.18),
            .init(color: DesignColor.positive.opacity(0.35), location: 0.55),
            .init(color: DesignColor.warning.opacity(0.5), location: 0.55),
            .init(color: DesignColor.critical.opacity(0.5), location: 0.64),
            .init(color: DesignColor.critical.opacity(0.5), location: 1.00)
        ]
    }
}
