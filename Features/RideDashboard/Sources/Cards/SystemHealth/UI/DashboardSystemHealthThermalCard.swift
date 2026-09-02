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
                DashboardThermalRangeGauge(range: range, usesBatteryThresholds: usesBatteryThresholds)
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
    }
}

private struct DashboardThermalRangeGauge: View {
    let range: DashboardSystemHealthViewData.ThermalRange
    let usesBatteryThresholds: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                track
                rangeMarker(width: proxy.size.width)
                averageMarker(width: proxy.size.width)
            }
        }
        .frame(height: Constants.trackHeight)
        .accessibilityHidden(true)
    }

    private var track: some View {
        Capsule()
            .fill(DesignColor.inactive)
            .overlay {
                if usesBatteryThresholds {
                    LinearGradient(
                        stops: Constants.batteryStops,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(Capsule())
                }
            }
    }

    private func rangeMarker(width: CGFloat) -> some View {
        let minimumX = xPosition(range.minimumCelsius, width: width)
        let maximumX = xPosition(range.maximumCelsius, width: width)
        return Capsule()
            .fill(markerColor.opacity(Constants.rangeOpacity))
            .frame(width: max(maximumX - minimumX, Constants.minimumRangeWidth), height: Constants.rangeHeight)
            .offset(x: minimumX)
    }

    private func averageMarker(width: CGFloat) -> some View {
        Circle()
            .fill(markerColor)
            .frame(width: Constants.averageMarkerSize, height: Constants.averageMarkerSize)
            .offset(x: xPosition(range.averageCelsius, width: width) - Constants.averageMarkerSize / 2)
    }

    private var markerColor: Color {
        usesBatteryThresholds ? DesignColor.primaryText : DesignColor.informational
    }

    private func xPosition(_ celsius: Double, width: CGFloat) -> CGFloat {
        let clamped = min(max(celsius, Constants.minimumCelsius), Constants.maximumCelsius)
        return (clamped - Constants.minimumCelsius)
            / (Constants.maximumCelsius - Constants.minimumCelsius)
            * width
    }

    private enum Constants {
        static let minimumCelsius = -10.0
        static let maximumCelsius = 100.0
        static let trackHeight: CGFloat = 14
        static let rangeHeight: CGFloat = 8
        static let averageMarkerSize: CGFloat = 14
        static let minimumRangeWidth: CGFloat = 4
        static let rangeOpacity = 0.7
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
